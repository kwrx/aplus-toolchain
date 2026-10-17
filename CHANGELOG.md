## 0.2.0 (2026-10-17)

### Feat

- add -pthread and -rdynamic support and per-arch dynamic linker to gcc specs

### Fix

- use musl crt1.o as start file in gcc specs
- use ld-musl-x86_64.so.1 as dynamic linker in gcc specs

## 0.1.1 (2026-10-11)

### Fix

- update aplus_musl version and correct download URL in build script

## 0.1.0 (2026-09-16)

### Feat

- add .cz.toml for commitizen configuration and update tag pattern in workflow files
