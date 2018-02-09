
# error codes 
const NO_ERROR = 0
const ERROR_INTERNAL = 1	        # unexpected error
# parse errors
const ERROR_BAD_ESCAPE = 2	        # bad escape sequence
const ERROR_BAD_CHAR_CLASS = 3	    # bad character class
const ERROR_BAD_CHAR_RANGE = 4	    # bad character class range
const ERROR_MISSING_BRACKET = 5	    # missing closing ]
const ERROR_MISSING_PAREN = 6	    # missing closing )
const ERROR_TRAILING_BACKSLASH = 7  # trailing \ at end of regexp
const ERROR_REPEAT_ARGUMENT = 8	    # repeat argument missing, e.g. "*"
const ERROR_REPEAT_SIZE = 9	        # bad repetition argument
const ERROR_REPEAT_OP = 10		    # bad repetition operator
const ERROR_BAD_PERL_OP = 11	    # bad perl operator
const ERROR_BAD_UTF8 = 12		    # invalid UTF-8 in regexp
const ERROR_BAD_NAMED_CAPTURE = 13	# bad named capture group
const ERROR_PATTERN_TOO_LARGE = 14	# pattern too large (compile failed)

# compile options
const UTF8 = 1
const Latin1 = 2

# bitmasks for compile options
const LOG_ERRORS =      UInt32(0x00000001)
const LATIN1 =          UInt32(0x00000002)
const LONGEST_MATCH =   UInt32(0x00000004)
const LITERAL =         UInt32(0x00000008)
const NEVER_NL =        UInt32(0x00000010)
const DOTALL =          UInt32(0x00000020)
const NEVER_CAPTURE =   UInt32(0x00000040)
const CASELESS =        UInt32(0x00000080)
const POSIX_SYNTAX =    UInt32(0x00000100)
const PERL_CLASSES =    UInt32(0x00000200)
const WORD_BOUNDARY =   UInt32(0x00000400)
const MULTILINE =       UInt32(0x00000800)
const COMPILE_MASK =    UInt32(0x00000fff)

# matching options
const UNANCHORED   = 1
const ANCHOR_START = 2
const ANCHOR_BOTH  = 3

# bitmasks for match options
const ANCHORED =        UInt32(0x00000001)
const ENDANCHORED =     UInt32(0x00000002)
const EXECUTE_MASK =    UInt32(0x00000003)

const DEFAULT_MAX_MEM = UInt32(0x00800000)  # 8 MB
