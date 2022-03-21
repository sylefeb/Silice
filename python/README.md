# Silice python package

**Warning**: This is very much work in progress, expect changes. There is
currently no documentation, please refer to the examples in `tests`.

## Build notes

Install cmake python build extension:

```pip install cmake-build-extension```

Make sure javac is in the path. Under MinGW if Silice was previously built, this should be enough (from a shell in this directory):

```export PATH=$PATH:../BUILD/jdk-14.0.1/bin/```

Build the extension:

```python3 setup.py build```

Install the extension:

```python3 setup.py install```

Enter the `tests` subdirectory and build something, e.g.

```python3 icebreaker_blinky.py```
