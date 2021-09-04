CALL antlr %1.g4
CALL jvc %1*.java
CALL antlr -Dlanguage=Cpp %1.g4
