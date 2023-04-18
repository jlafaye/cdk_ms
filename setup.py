# -----------------------------------------------------------------------------
# setup.py
# copyright cfm
#
# project:  data-ms-primebrokerage
# author:   msalor
# created:  2023-04-18
#
# -----------------------------------------------------------------------------


import os
import re

from setuptools import setup, find_packages


def get_requirements(filename='requirements.txt'):
    ret = []
    if os.path.isfile(filename):
        for x in open(filename):
            ret.append(x.strip())
    return ret


def get_version(dir_name):
    for x in open(os.path.join(dir_name, '__version__.py')):
        x = [y.strip() for y in x.split('=', 1)]
        if len(x) == 2 and x[0] == '__version__':
            match = re.match(r"^['\"](\d+\.\d+\.\d+\w*)['\"]", x[1].strip())
            if match:
                return match.group(1)
            # If we do not have a match, we try to eval __version__
            return eval(x[1])
    raise ValueError('__version__ not found in __version__.py')


def get_scripts(dir_name):
    ret = []
    if os.path.isdir(dir_name):
        for fn in os.listdir(dir_name):
            ret.append(os.path.join(dir_name, fn))
    return ret


def get_data(dir_name):
    ret = []
    if os.path.isdir(dir_name):
        for d, a, l in os.walk(dir_name):
            ret.append((d, [os.path.join(d, x) for x in l]))
    return ret


setup(
    name='data-ms-primebrokerage',
    setup_requires=['setuptools_scm'],
    use_scm_version=True,
    author='it-data-financial',
    author_email='it-data-financial@cfm.fr',
    maintainer='msalor',
    maintainer_email='msalor@cfm.fr',
    description='',
    long_description='',
    install_requires=get_requirements(),
    packages=find_packages('.', exclude=('tests', 'env', 'docs', 'build')),
    license='cfm proprietary',
    url='https://confluence.fr.cfm.fr/')
