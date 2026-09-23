const String toolRouterGbnf = r'''
root         ::= tool-call | plain-text
tool-call    ::= time-tag | memory-tag | search-tag
agent-tag    ::= "<agent>" text "</agent>"
time-tag     ::= "<time/>"
memory-tag   ::= "<memory>" mem-op ":" text "</memory>"
mem-op       ::= "read" | "write"
search-tag   ::= "<search>" text "</search>"
plain-text   ::= [^<]+
text         ::= [^<]+
''';
