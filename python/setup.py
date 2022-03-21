import cmake_build_extension
import setuptools
import shutil

from pathlib import Path

def add_asset_directory(dir):
    shutil.copytree('../{}'.format(dir),'./silice/{}'.format(dir))
    datadir = Path(__file__).parent / 'silice/{}'.format(dir)
    return [str(p.relative_to(Path(__file__).parent / 'silice')) for p in datadir.rglob('*')]

files = add_asset_directory('frameworks')

setuptools.setup(
    name='silice',
    version='0.1',
    author='Sylvain Lefebvre',
    author_email='sylvain.lefebvre@inria.fr',
    description='Silice python module',
    ext_modules=[
        cmake_build_extension.CMakeExtension(
            name="_silice",
        )
    ],
    cmdclass=dict(
        build_ext=cmake_build_extension.BuildExtension,
    ),
    long_description='',
    zip_safe=False,
    packages=setuptools.find_packages(),
    package_data={'': ['*.dll','*.so',*files] },
    include_package_data=True,
)

shutil.rmtree('./silice/frameworks')
