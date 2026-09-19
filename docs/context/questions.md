# Questions

## Token compatibility

Finologee authenticates the TPP from its eIDAS certificate, and uses OIDC to authorise that TPP
to access the PSU's accounts and to initiate payments.

Inside the bank, Ping Federate is the solution that issues the tokens used to reach the bank's
APIs.

**How do we ensure that the tokens Finologee issues and the tokens Ping Federate accepts work
together?**
