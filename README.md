# Core

## Configuration

* Define environment variable for custom Nerves System:

```
export NERVES_SYSTEM=*Path To Nerves System*
export NERVES_SYSTEM_CACHE=none
export NERVES_SYSTEM_COMPILER=local
```

* Configure your network:

```
TODO
```

## Build

```
cd apps/brain
mix deps.get
mix compile
```

## Run

```
cd apps/brain
iex -S mix
```

## Release
```
cd apps/brain
MIX_ENV=prod mix firmware
```

