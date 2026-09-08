import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { readFileSync } from 'node:fs';
import { join, extname } from 'node:path';
import { banks } from './registry.js';
import { connectionOf, connectionsOf, forget } from './connections.js';
import { accountsOf, completeConnection, startConnection } from './orchestrator.js';
import { problemFor } from './problems.js';

/**
 * The TPP's backend-for-frontend.
 *
 * It holds the QWAC, the tokens and the PKCE verifier; the browser holds none of them.
 * That is not only good practice — a token in a browser could not be used anyway, since
 * it is bound to the certificate this process presents.
 */
const port = Number(process.env['PORT'] ?? 5173);
const webRoot = process.env['WEB_ROOT'] ?? join(import.meta.dirname, '../../tpp-web/dist');

/**
 * Who is using the app.
 *
 * A cookie rather than a real session store — this is the TPP's own login, entirely
 * separate from the bank authentication that happens later, and conflating the two is
 * exactly the confusion the journey is meant to avoid.
 */
const users: Record<string, string> = { anna: 'Anna Müller', ben: 'Ben Weber' };

const userOf = (request: IncomingMessage): string | undefined => {
  const cookie = /(?:^|;\s*)tpp_user=([^;]+)/.exec(request.headers.cookie ?? '');
  const user = cookie?.[1];
  return user !== undefined && user in users ? user : undefined;
};

const json = (response: ServerResponse, status: number, body: unknown): void => {
  const text = JSON.stringify(body);
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(text);
};

/** The PSU's address, forwarded to the Bank so a read counts as PSU-present. */
const psuIpOf = (request: IncomingMessage): string | undefined =>
  (request.headers['x-forwarded-for'] as string | undefined) ??
  request.socket.remoteAddress ??
  undefined;

const contentTypes: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
};

const serveStatic = (response: ServerResponse, file: string): void => {
  try {
    const body = readFileSync(join(webRoot, file));
    response.writeHead(200, { 'Content-Type': contentTypes[extname(file)] ?? 'text/plain' });
    response.end(body);
  } catch {
    response.writeHead(404).end('not found');
  }
};

const server = createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', `http://localhost:${port}`);

  try {
    // ---- who is signed in --------------------------------------------------------
    if (url.pathname === '/api/me') {
      const user = userOf(request);
      return json(response, 200, user
        ? { userId: user, displayName: users[user] }
        : { userId: null, choices: Object.entries(users).map(([id, name]) => ({ id, name })) });
    }

    if (url.pathname === '/api/signin' && request.method === 'POST') {
      const user = url.searchParams.get('userId') ?? '';
      if (!(user in users)) return json(response, 400, { message: 'unknown user' });
      response.setHeader('Set-Cookie', `tpp_user=${user}; Path=/; SameSite=Lax`);
      return json(response, 200, { userId: user, displayName: users[user] });
    }

    if (url.pathname === '/api/signout' && request.method === 'POST') {
      response.setHeader('Set-Cookie', 'tpp_user=; Path=/; Max-Age=0');
      return json(response, 204, null);
    }

    // Everything below needs a signed-in user.
    const currentUser = userOf(request);
    if (url.pathname.startsWith('/api/') && currentUser === undefined) {
      return json(response, 401, { message: 'sign in first' });
    }

    // ---- the API the browser talks to -------------------------------------------
    if (url.pathname === '/api/banks') {
      const connections = connectionsOf(currentUser!);
      return json(response, 200, {
        banks: banks().map((bank) => {
          const connection = connections.find((c) => c.bankId === bank.bankId);
          return {
            bankId: bank.bankId,
            displayName: bank.displayName,
            logo: bank.logo,
            state: connection?.state ?? 'selected',
            connectedAt: connection?.connectedAt ?? null,
            accountCount: connection?.accounts?.length ?? null,
          };
        }),
      });
    }

    if (url.pathname === '/api/connect' && request.method === 'POST') {
      const bankId = url.searchParams.get('bankId') ?? 'bank';
      try {
        const started = await startConnection(currentUser!, bankId, psuIpOf(request));
        return json(response, 200, { authorizeUrl: started.authorizeUrl });
      } catch (failure) {
        return json(response, 502, { problem: problemFor(String((failure as Error).message)) });
      }
    }

    // The Bank redirects the browser here after the PSU has approved.
    if (url.pathname === '/xs2a/callback/bank') {
      const state = url.searchParams.get('state') ?? '';
      try {
        const connection = await completeConnection(
          state,
          url.searchParams.get('code') ?? undefined,
          url.searchParams.get('error') ?? undefined,
        );
        // Redirect into the app rather than rendering here, so a reload of the final
        // URL is a page view and not a second callback.
        const target = connection.state === 'connected'
          ? `/#/connected/${connection.bankId}`
          : `/#/problem/${connection.lastError ?? 'TOKEN_EXCHANGE_FAILED'}`;
        response.writeHead(302, { Location: target }).end();
        return;
      } catch (failure) {
        // Only an unrecognised state is a state mismatch. Everything else — the Bank
        // unreachable, TLS refused, the token endpoint erroring — used to be reported
        // as one too, which sent whoever was debugging it looking in the wrong place.
        const reason = String((failure as Error).message);
        process.stderr.write(`callback failed: ${reason}\n`);
        const problem = reason === 'STATE_MISMATCH' ? 'STATE_MISMATCH' : 'BANK_UNREACHABLE';
        response.writeHead(302, { Location: `/#/problem/${problem}` }).end();
        return;
      }
    }

    if (url.pathname === '/api/accounts') {
      const bankId = url.searchParams.get('bankId') ?? 'bank';
      const result = await accountsOf(currentUser!, bankId, psuIpOf(request));
      return json(response, 200, {
        accounts: result.accounts,
        stale: result.stale,
        problem: result.problem ? problemFor(result.problem) : null,
        state: connectionOf(currentUser!, bankId).state,
      });
    }

    if (url.pathname === '/api/disconnect' && request.method === 'POST') {
      forget(currentUser!, url.searchParams.get('bankId') ?? 'bank');
      return json(response, 204, null);
    }

    if (url.pathname.startsWith('/api/problem/')) {
      return json(response, 200, problemFor(url.pathname.split('/').pop()));
    }

    // ---- the app ------------------------------------------------------------------
    if (url.pathname === '/' || url.pathname === '/index.html') return serveStatic(response, 'index.html');
    if (url.pathname === '/app.js') return serveStatic(response, 'app.js');
    if (url.pathname === '/app.css') return serveStatic(response, 'app.css');
    response.writeHead(404).end('not found');
  } catch (unexpected) {
    json(response, 500, { problem: problemFor(undefined), detail: String(unexpected) });
  }
});

server.listen(port, () => {
  process.stdout.write(`TPP listening on http://localhost:${port}\n`);
});
