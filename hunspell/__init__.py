__all__ = ['hunspell']

from ._version import __version__  # noqa: F401
from .hunspell import HunspellWrap as Hunspell, HunspellFilePathError  # noqa: F401
forkBy = 'cdhigh'
