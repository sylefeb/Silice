
SRC_DIR         ?= ./src
BUILD_DIR       ?= ./build

DOCS_CFG        ?= .doxygen

LEX_SRC         ?= $(SRC_DIR)/VCDScanner.l
LEX_OUT         ?= $(SRC_DIR)/VCDScanner.cpp
LEX_HEADER      ?= $(SRC_DIR)/VCDScanner.hpp
LEX_OBJ         ?= $(BUILD_DIR)/VCDScanner.o

YAC_SRC         ?= $(SRC_DIR)/VCDParser.ypp
YAC_OUT         ?= $(SRC_DIR)/VCDParser.cpp
YAC_HEADER      ?= $(SRC_DIR)/VCDParser.hpp
YAC_OBJ         ?= $(BUILD_DIR)/VCDParser.o

CXXFLAGS        += -I$(BUILD_DIR) -I$(SRC_DIR) -g -std=c++0x

VCD_SRC         ?= $(SRC_DIR)/VCDFile.cpp \
                   $(SRC_DIR)/VCDValue.cpp \
                   $(SRC_DIR)/VCDFileParser.cpp

VCD_OBJ_FILES   = $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(VCD_SRC)) $(YAC_OBJ) $(LEX_OBJ)

TEST_APP        ?= $(BUILD_DIR)/vcd-parse

all : vcd-parser docs $(BUILD_DIR)/libverilog-vcd-parser.a

vcd-parser: $(TEST_APP)

parser-srcs: $(YAC_OUT) $(LEX_OUT)

docs: $(DOCS_CFG) $(VCD_SRC) $(TEST_FILE)
	doxygen $(DOCS_CFG)

$(BUILD_DIR)/libverilog-vcd-parser.a: $(VCD_OBJ_FILES)
	ar rcs $@ $^
	cp $(SRC_DIR)/*.hpp $(BUILD_DIR)/

$(BUILD_DIR)/%.o :  $(LEX_OBJ) $(YAC_OBJ) $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $^

$(YAC_OUT) : $(YAC_SRC)
	bison -v --defines=$(YAC_HEADER) $(YAC_SRC) -o $(YAC_OUT)

$(LEX_OUT) : $(LEX_SRC) $(YAC_OUT)
	flex  -P VCDParser --header-file=$(LEX_HEADER) -o $(LEX_OUT) $(LEX_SRC)

$(TEST_APP) : $(TEST_FILE) $(SRC_DIR)/VCDStandalone.cpp $(VCD_OBJ_FILES)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -rf $(LEX_OUT) $(LEX_HEADER) $(LEX_OBJ) \
           $(YAC_OUT) $(YAC_HEADER) $(YAC_OBJ) \
           position.hh stack.hh location.hh VCDParser.output $(TEST_APP)
