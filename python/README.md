# Silice python package

**Warning**: This is very much work in progress, expect changes. There is
currently no documentation, please refer to the examples in `tests`.

## Build notes

Make sure all submodules are up to date:

```git submodule init```

```git submodule update```

Install cmake python build extension:

```pip install cmake-build-extension```

The python `distutils` might be need to be installed ```sudo apt install python3-distutils```.

Make sure javac is in the path. Under MinGW if Silice was previously built, this should be enough (from a shell in this directory):

```export PATH=$PATH:../BUILD/jdk-14.0.1/bin/```

Build the extension:

```python3 setup.py build```

Install the extension:

```python3 setup.py install```
(might need to `sudo`)

Prior to testing, install migen and litex

```pip install migen```

```pip install litex```

```pip install litex_boards```

Enter the `tests` subdirectory and build something, e.g.

```python3 icebreaker_blinky.py```
