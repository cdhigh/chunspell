import os
from locale import getpreferredencoding

from libc.stdlib cimport *
from libc.string cimport *
from cython.operator cimport dereference as deref

class HunspellFilePathError(IOError):
    pass

WIN32_LONG_PATH_PREFIX = "\\\\?\\"

ctypedef enum action_type:
    add,
    remove,
    stem,
    analyze,
    spell,
    suggest,
    suffix_suggest

cdef action_type action_to_enum(basestring action):
    if action == 'add':
        return add
    elif action == 'remove':
        return remove
    elif action == 'spell':
        return spell
    elif action == 'analyze':
        return analyze
    elif action == 'stem':
        return stem
    elif action == 'suggest':
        return suggest
    elif action == 'suffix_suggest':
        return suffix_suggest
    else:
        raise ValueError("Unexpected action {} for hunspell".format(action))

cdef basestring action_to_string(action_type action_e):
    if action_e == add:
        return 'add'
    elif action_e == remove:
        return 'remove'
    elif action_e == spell:
        return 'spell'
    elif action_e == analyze:
        return 'analyze'
    elif action_e == stem:
        return 'stem'
    elif action_e == suggest:
        return 'suggest'
    elif action_e == suffix_suggest:
        return 'suffix_suggest'
    else:
        raise ValueError("Unexpected action {} for hunspell".format(action_e))

def valid_encoding(basestring encoding):
    try:
        "".encode(encoding, 'strict')
        return encoding
    except LookupError:
        return 'ascii'

cdef int copy_to_c_string(basestring py_string, char **holder, basestring encoding) except -1:
    if isinstance(py_string, bytes):
        return byte_to_c_string(<bytes>py_string, holder, encoding)
    else:
        return byte_to_c_string(<bytes>py_string.encode(encoding, 'strict'), holder, encoding)

cdef int byte_to_c_string(bytes py_byte_string, char **holder, basestring encoding) except -1:
    cdef size_t str_len = len(py_byte_string)
    cdef char *c_raw_string = py_byte_string
    holder[0] = <char *>malloc((str_len + 1) * sizeof(char)) # deref doesn't support left-hand assignment
    if deref(holder) is NULL:
        raise MemoryError()
    strncpy(deref(holder), c_raw_string, str_len)
    holder[0][str_len] = 0
    return str_len

cdef unicode c_string_to_unicode_no_except(char* s, basestring encoding):
    # Convert c_string to python unicode
    try:
        return s.decode(encoding, 'strict')
    except UnicodeDecodeError:
        return u""

#//////////////////////////////////////////////////////////////////////////////
cdef class HunspellWrap(object):
    # C-realm properties
    cdef Hunspell *_cxx_hunspell
    cdef public basestring lang
    cdef public basestring _hunspell_dir
    cdef public basestring _dic_encoding
    cdef public basestring _system_encoding
    cdef char *affpath
    cdef char *dpath

    cdef basestring prefix_win_utf8_hunspell_path(self, basestring path):
        if os.name == 'nt' and self._system_encoding.lower().replace('-', '') == 'utf8':
            return WIN32_LONG_PATH_PREFIX + path
        else:
            return path

    cdef Hunspell *_create_hspell_inst(self, basestring lang) except *:
        # C-realm Create Hunspell Instance
        if self.affpath:
            free(self.affpath)
        self.affpath = NULL
        if self.dpath:
            free(self.dpath)
        self.dpath = NULL
        cdef Hunspell *holder = NULL

        pyaffpath = os.path.join(self._hunspell_dir, '{}.aff'.format(lang))
        pydpath = os.path.join(self._hunspell_dir, '{}.dic'.format(lang))
        for fpath in (pyaffpath, pydpath):
            if not os.path.isfile(fpath) or not os.access(fpath, os.R_OK):
                raise HunspellFilePathError("File '{}' not found or accessible".format(fpath))

        next_str = pyaffpath
        try:
            copy_to_c_string(
                self.prefix_win_utf8_hunspell_path(pyaffpath),
                &self.affpath,
                self._system_encoding
            )
            next_str = pydpath
            copy_to_c_string(
                self.prefix_win_utf8_hunspell_path(pydpath),
                &self.dpath,
                self._system_encoding
            )
        except UnicodeEncodeError as e:
            raise HunspellFilePathError(
                "File path ('{path}') encoding did not match locale encoding ('{enc}'): {err}".format(
                    path=next_str, enc=self._system_encoding, err=str(e))
            )
        holder = new Hunspell(self.affpath, self.dpath)
        if holder is NULL:
            raise MemoryError()

        return holder

    def __init__(self, basestring lang='en_US', basestring hunspell_data_dir=None,
            basestring system_encoding=None):
        if hunspell_data_dir is None:
            hunspell_data_dir = os.environ.get("HUNSPELL_DATA")
        if hunspell_data_dir is None:
            hunspell_data_dir = os.path.join(os.path.dirname(__file__), 'dictionaries')
        if system_encoding is None:
            system_encoding = os.environ.get("HUNSPELL_PATH_ENCODING") or getpreferredencoding()
        self._hunspell_dir = os.path.abspath(hunspell_data_dir)
        self._system_encoding = system_encoding

        self.lang = lang
        self._cxx_hunspell = self._create_hspell_inst(lang)
        # csutil.hxx defines the encoding for this value as #define SPELL_ENCODING "ISO8859-1"
        self._dic_encoding = valid_encoding(c_string_to_unicode_no_except(self._cxx_hunspell.get_dic_encoding(), 'ISO8859-1'))
        
    def __dealloc__(self):
        del self._cxx_hunspell
        if self.affpath is not NULL:
            free(self.affpath)
        if self.dpath is not NULL:
            free(self.dpath)

    def add_dic(self, basestring dpath, basestring key=None):
        # Python load extra dictionaries
        cdef char *c_path = NULL
        cdef char *c_key = NULL
        copy_to_c_string(dpath, &c_path, 'UTF-8')
        try:
            if key:
                copy_to_c_string(key, &c_key, 'UTF-8')
            try:
                return self._cxx_hunspell.add_dic(c_path, c_key)
            finally:
                if c_key is not NULL:
                    free(c_key)
        finally:
            if c_path is not NULL:
                free(c_path)

    def add(self, basestring word, basestring example=None):
        # Python add individual word to dictionary
        cdef char *c_word = NULL
        cdef char *c_example = NULL
        copy_to_c_string(word, &c_word, self._dic_encoding)
        try:
            if example:
                copy_to_c_string(example, &c_example, self._dic_encoding)
                try:
                    return self._cxx_hunspell.add_with_affix(c_word, c_example)
                finally:
                    if c_example is not NULL:
                        free(c_example)
            else:
                return self._cxx_hunspell.add(c_word)
        finally:
            if c_word is not NULL:
                free(c_word)

    def add_with_affix(self, basestring word, basestring example):
        return self.add(word, example)

    def remove(self, basestring word):
        # Python remove individual word from dictionary
        cdef char *c_word = NULL
        copy_to_c_string(word, &c_word, self._dic_encoding)
        try:
            return self._cxx_hunspell.remove(c_word)
        finally:
            if c_word is not NULL:
                free(c_word)

    def spell(self, basestring word):
        # Python individual word spellcheck
        cdef char *c_word = NULL
        copy_to_c_string(word, &c_word, self._dic_encoding)
        try:
            return self._cxx_hunspell.spell(c_word) != 0
        finally:
            if c_word is not NULL:
                free(c_word)

    def analyze(self, basestring word):
        # Python individual word analyzing
        return self.c_tuple_action(analyze, word)

    def stem(self, basestring word):
        # Python individual word stemming
        return self.c_tuple_action(stem, word)

    def suggest(self, basestring word):
        # Python individual word suggestions
        return self.c_tuple_action(suggest, word)

    def suffix_suggest(self, basestring word):
        # Python individual word suffix suggestions
        return self.c_tuple_action(suffix_suggest, word)

    def action(self, basestring action, basestring word):
        cdef action_type action_e = action_to_enum(action)
        if action_e == add:
            return self.add(word)
        elif action_e == remove:
            return self.remove(word)
        elif action_e == spell:
            return self.spell(word)
        else:
            return self.c_tuple_action(action_e, word)

    ###################
    # C-Operations
    ###################

    cdef tuple c_tuple_action(self, action_type action_e, basestring word):
        cdef char **s_list = NULL
        cdef char *c_word = NULL
        cdef list results_list
        cdef tuple result

        copy_to_c_string(word, &c_word, self._dic_encoding)

        try:
            if action_e == stem:
                count = self._cxx_hunspell.stem(&s_list, c_word)
            elif action_e == analyze:
                count = self._cxx_hunspell.analyze(&s_list, c_word)
            elif action_e == suggest:
                count = self._cxx_hunspell.suggest(&s_list, c_word)
            elif action_e == suffix_suggest:
                count = self._cxx_hunspell.suffix_suggest(&s_list, c_word)
            else:
                raise ValueError("Unexpected tuple action {} for hunspell".format(action_to_string(action_e)))

            results_list = []
            for i from 0 <= i < count:
                results_list.append(c_string_to_unicode_no_except(s_list[i], self._dic_encoding))
            self._cxx_hunspell.free_list(&s_list, count)

            return tuple(results_list)
        finally:
            if c_word is not NULL:
                free(c_word)
