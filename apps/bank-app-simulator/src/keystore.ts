/**
 * The device's key, held the way a phone would hold it.
 *
 * The private key is generated **non-extractable**, so nothing — not this code, not the
 * console, not an injected script — can read it out. It is stored as a `CryptoKey` in
 * IndexedDB rather than as bytes, which is exactly the guarantee a secure enclave gives:
 * the key can be *used* here and never *taken* from here.
 */
const DB = 'bank-app-simulator';
const STORE = 'device';
const RECORD = 'keypair';

interface StoredDevice {
  readonly keys: CryptoKeyPair;
  deviceId?: string;
}

const open = (): Promise<IDBDatabase> =>
  new Promise((resolve, reject) => {
    const request = indexedDB.open(DB, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });

const transact = async <T>(
  mode: IDBTransactionMode,
  run: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> => {
  const db = await open();
  return new Promise<T>((resolve, reject) => {
    const request = run(db.transaction(STORE, mode).objectStore(STORE));
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
};

export const loadDevice = (): Promise<StoredDevice | undefined> =>
  transact('readonly', (store) => store.get(RECORD) as IDBRequest<StoredDevice | undefined>);

const save = (device: StoredDevice): Promise<IDBValidKey> =>
  transact('readwrite', (store) => store.put(device, RECORD));

/**
 * Returns the device's key, generating one on first visit.
 *
 * A reload finds the same key: that is what makes this a *device* rather than a session.
 */
export const deviceKeys = async (): Promise<StoredDevice> => {
  const existing = await loadDevice();
  if (existing) return existing;

  const keys = await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    false, // non-extractable: the private half can never leave this browser
    ['sign', 'verify'],
  );
  const device: StoredDevice = { keys };
  await save(device);
  return device;
};

export const rememberEnrolment = async (deviceId: string): Promise<void> => {
  const device = await deviceKeys();
  await save({ keys: device.keys, deviceId });
};

/** The public half, in the JWK form the CIAM accepts at enrolment. */
export const publicJwk = async (keys: CryptoKeyPair): Promise<JsonWebKey> =>
  crypto.subtle.exportKey('jwk', keys.publicKey);

/** ECDSA P-256 over SHA-256, base64url without padding — what the CIAM verifies. */
export const sign = async (keys: CryptoKeyPair, message: string): Promise<string> => {
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    keys.privateKey,
    new TextEncoder().encode(message),
  );
  return toDer(new Uint8Array(signature));
};

/**
 * WebCrypto emits the raw r‖s pair; Java's `SHA256withECDSA` expects a DER SEQUENCE.
 * Converting here keeps the difference where it belongs — in the device, not in the
 * Bank's verifier, which should not have to know what produced a signature.
 */
const toDer = (raw: Uint8Array): string => {
  const half = raw.length / 2;
  const trim = (bytes: Uint8Array): number[] => {
    let start = 0;
    while (start < bytes.length - 1 && bytes[start] === 0) start++;
    const value = [...bytes.slice(start)];
    // A leading bit of 1 would read as negative, so DER prefixes a zero byte.
    return (value[0]! & 0x80) !== 0 ? [0, ...value] : value;
  };
  const r = trim(raw.slice(0, half));
  const s = trim(raw.slice(half));
  const body = [0x02, r.length, ...r, 0x02, s.length, ...s];
  const der = Uint8Array.from([0x30, body.length, ...body]);
  return btoa(String.fromCharCode(...der))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};
