./antlr.sh $1.g4
./jvc.sh $1*.java
./antlr.sh -Dlanguage=Cpp $1.g4
