import cmake_build_extension
import setuptools
import shutil

from pathlib import Path

def add_asset_directory(dir):
    try:
        shutil.copytree('../{}'.format(dir),'./silice/{}'.format(dir))
    except:
        print("files already copied")
    datadir = Path(__file__).parent / 'silice/{}'.format(dir)
    return [str(p.relative_to(Path(__file__).parent / 'silice')) for p in datadir.rglob('*')]

# Add the content of 'frameworks' as package files
files = add_asset_directory('frameworks')

# Setup
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

# Cleanup the local copy of framework files
shutil.rmtree('./silice/frameworks')
