# pavelhorak/tap

Homebrew formulae by Pavel Horak.

## Pion

[Pion](https://github.com/pavelhorak/pion) is a memory engine for AI
inference, wire-compatible with Redis. The formula is for macOS 14 or later on
Apple Silicon.

```bash
brew install pavelhorak/tap/pion
brew services start pion        # 127.0.0.1:1974; restarts at login and after a crash
redis-cli -p 1974 PING          # +PONG
```

The service runs with `--kvcache --metal-attention --nle-embed`, so Pion's
prompt cache (`pion-vllm-mlx`) and semantic cache work against it as installed.
As a service, Pion keeps its WAL, snapshots and crash log in
`$(brew --prefix)/var/pion` and logs to `$(brew --prefix)/var/log/pion.log`.
Run by hand (`pion-server`), it writes them to the directory you start it from.

On Linux, use the [release tarballs](https://github.com/pavelhorak/pion/releases/latest)
or `ghcr.io/pavelhorak/pion`.

The formula installs the tarball that Pion's own release workflow builds. The
`bump` workflow here checks for a new Pion release every six hours, installs
and tests it, and only then points the formula at it.
