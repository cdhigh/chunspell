
# cHunSpell
Cython wrapper on Hunspell Dictionary

## Description

This fork is based on <https://github.com/MSeal/cython_hunspell> and modified to reduce dependencies by removing caching and batch functionalities. Apart from Hunspell itself, there are no other third-party dependencies.     
Additional, providing precompiled wheels for multiple platforms.

-------------------------------------------------

This repository provides a wrapper on Hunspell to be used natively in Python. The
module uses cython to link between the C++ and Python code, with some additional
features. There's very little Python overhead as all the heavy lifting is done
on the C++ side of the module interface, which gives optimal performance.

## Installing

For the simplest install simply run:

```python
pip install chunspell
```

This will install the hunspell 1.7.2 C++ bindings on your behalf for your platform.


### hunspell

The library installs [hunspell](http://hunspell.github.io/) version 1.7.2. As new version of hunspell become
available this library will provide new versions to match.

## Features

Spell checking & spell suggestions
* See http://hunspell.github.io/

## How to use

Below are some simple examples for how to use the repository.

### Creating a Hunspell object

```python
from hunspell import Hunspell
h = Hunspell()
```

You now have a usable hunspell object that can make basic queries for you.

```python
h.spell('test') # True
```

### Spelling

It's a simple task to ask if a particular word is in the dictionary.

```python
h.spell('correct') # True
h.spell('incorect') # False
```

This will only ever return True or False, and won't give suggestions about why it
might be wrong. It also depends on your choice of dictionary.

### Suggestions

If you want to get a suggestion from Hunspell, it can provide a corrected label
given a basestring input.

```python
h.suggest('incorect') # ('incorrect', 'correction', corrector', 'correct', 'injector')
```

The suggestions are in sorted order, where the lower the index the closer to the
input string.

#### Suffix Match

```python
h.suffix_suggest('do') # ('doing', 'doth', 'doer', 'doings', 'doers', 'doest')
```

### Stemming

The module can also stem words, providing the stems for pluralization and other
inflections.

```python
h.stem('testers') # ('tester', 'test')
h.stem('saves') # ('save',)
```

#### Analyze

Like stemming but return morphological analysis of the input instead.

```python
h.analyze('permanently') # (' st:permanent fl:Y',)
```

### Dictionaries

You can also specify the language or dictionary you wish to use.

```python
h = Hunspell('en_US') # Canadian English
```

By default you have the only `en_US` dictionaries available.

However you can download your own and point Hunspell to your custom dictionaries.

```python
h = Hunspell('en_GB-large', hunspell_data_dir='/custom/dicts/dir')
```

#### Adding Dictionaries

You can also add new dictionaries at runtime by calling the add_dic method.

```python
h.add_dic(os.path.join(PATH_TO, 'special.dic'))
```

#### Adding words

You can add individual words to a dictionary at runtime.

```python
h.add('sillly')
```

Furthermore you can attach an affix to the word when doing this by providing a
second argument

```python
h.add('silllies', "is:plural")
```

#### Removing words

Much like adding, you can remove words.

```python
h.remove(word)
```

## Language Preferences

* Google Style Guide
* Object Oriented (with a few exceptions)

## Known Workarounds

- On Windows very long file paths, or paths saved in a different encoding than the system require special handling by Hunspell to load dictionary files. To circumvent this on Windows setups, either set `system_encoding='UTF-8'` in the `Hunspell` constructor or set the environment variable `HUNSPELL_PATH_ENCODING=UTF-8`. Then you must re-encode your `hunspell_data_dir` in UTF-8 by passing that argument name to the `Hunspell` constructor or setting the `HUNSPELL_DATA` environment variable. This is a restriction of Hunspell / Windows operations.

## Author
Author(s): Tim Rodriguez, Matthew Seal, cdhigh

## License
MIT
