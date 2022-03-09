import inspect
import os
import sys
from pathlib import Path

import cmake_build_extension
import setuptools

setuptools.setup(
    name='silice',
    version='0.1',
    author='Sylvain Lefebvre',
    author_email='sylvain.lefebvre@inria.fr',
    description='Silice python module',
    ext_modules=[
    cmake_build_extension.CMakeExtension(name="_silice")
    ],
    cmdclass=dict(
        build_ext=cmake_build_extension.BuildExtension,
    ),
    long_description='',
    zip_safe=False,
    packages=['silice']
)
