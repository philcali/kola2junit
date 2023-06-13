# Kola 2 JUnit

What's [kola][1]? A testing framework for CoreOS distributions.
The framework is awesome, and provides an incredible amount of
report data. The only thing missing is the ability to convert
it's `report.json` into something that traditional CI/CD systems
can ingest. Enter `kola2junit`, which is a containerized application
to do just that.

## Docker Build Image

```
docker build -t kola2junit .
```

## Build a CoreOS Distribution

```
mkdir fcos
cd fcos
cosa init --branch stable https://github.com/coreos/fedora-coreos-config
cosa fetch
cosa build
```

## Test the Distrbution

```
cosa kola run
```

## Convert the Report to JUnit

```
cat tmp/kola/reports/report.json | docker run --rm \
    --interactive \
    --name kolaconvert \
    -v $PWD/tmp/kola:/working \
    kola2junit -n "Kola Run: $(jq -r '.distro + " - " + .platform' < tmp/kola/properties.json)" > tmp/kola/report.xml
```

## Use in CodeBuild

Update your buildspec:

``` yaml
reports:
 kola-run:
   files:
     - '**/*'
   base-directory: 'tmp/kola'
```

[1]: https://coreos.github.io/coreos-assembler/kola/
