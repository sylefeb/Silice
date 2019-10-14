/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "siliceLexer.h"
#include "siliceParser.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <unordered_set>
#include <unordered_map>

#include <LibSL/LibSL.h>

#include "path.h"

// -------------------------------------------------

#define FF_D      "_d"
#define FF_Q      "_q"
#define REG_      "_r"
#define WIRE      "_w"

#define ALG_INPUT  "in"
#define ALG_OUTPUT "out"
#define ALG_INOUT  "inout"
#define ALG_IDX    "index"
#define ALG_RUN    "run"
#define ALG_RETURN "return"
#define ALG_DONE   "done"
#define ALG_CLOCK  "clock"
#define ALG_RESET  "reset"

// -------------------------------------------------

class Module;

// -------------------------------------------------

/// \brief class to parse, store and compile an algorithm definition
class Algorithm
{
private:

  /// \brief base types
  enum e_Type { Int, UInt };

  /// \brief algorithm name
  std::string m_Name;

  /// \brief algorithm clock
  std::string m_Clock = ALG_CLOCK;

  /// \brief algorithm reset
  std::string m_Reset = ALG_RESET;

  /// \brief whether algorithm autorun at startup
  bool m_AutoRun = false;

  /// \brief Set of known modules so far
  const std::unordered_map<std::string, AutoPtr<Module> >& m_KnownModules;

  /// \brief enum for variable access
  /// e_ReadWrite = e_ReadOnly | e_WriteOnly
  enum e_Access { e_NotAccessed = 0, e_ReadOnly = 1, e_WriteOnly = 2, e_ReadWrite = 3, e_WriteBinded = 4 };

  /// \brief enum for variable type
  enum e_VarUsage { e_Undetermined = 0, e_NotUsed = 1, e_Const = 2, e_Temporary = 3, e_FlipFlop = 4, e_Bound = 5, e_Assigned = 6 };

  /// \brief enum for IO types
  enum e_IOType { e_Input, e_Output, e_InOut, e_NotIO };

  /// \brief info about variables, inputs, outputs
  typedef struct {
    std::string name;
    e_Type      base_type;
    int         width;
    std::vector<std::string> init_values;
    int         table_size; // 0: not a table, otherwise size
    e_Access    access = e_NotAccessed;
    e_VarUsage  usage  = e_Undetermined;
  } t_var_nfo;

  /// \brief typedef to distinguish vars from ios
  typedef t_var_nfo t_inout_nfo;

  /// \brief inputs
  std::vector< t_inout_nfo > m_Inputs;
  /// \brief outputs
  std::vector< t_inout_nfo > m_Outputs;
  /// \brief inouts NOTE: for now can only be passed to verilog modules
  std::vector< t_inout_nfo > m_InOuts;

  /// \brief all input names, map contains index in m_Inputs
  std::unordered_map<std::string, int > m_InputNames;
  /// \brief all output names, map contains index in m_Outputs
  std::unordered_map<std::string, int > m_OutputNames;
  /// \brief all inout names, map contains index in m_InOuts
  std::unordered_map<std::string, int > m_InOutNames;

  /// \brief VIO (variable-or-input-or-output) bound to module/algorithms inputs (regs) or outputs (wires) (name => reg/wire name)
  std::unordered_map<std::string, std::string> m_VIOBoundToModAlgOutputs;

  /// \brief declared variables
  std::vector< t_var_nfo >    m_Vars;
  /// \brief all varnames, map contains index in m_Vars
  std::unordered_map<std::string, int > m_VarNames;

  /// \brief enum binding direction
  enum e_BindingDir { e_Left, e_Right, e_BiDir };

  /// \brief records info about variable bindings
  typedef struct
  {
    std::string  left;
    std::string  right;
    e_BindingDir dir;
    int          line; // for error reporting
  } t_binding_nfo;

  /// \brief info about an instanced algorithm
  typedef struct {
    std::string                algo_name;
    std::string                instance_name;
    std::string                instance_clock;
    std::string                instance_reset;
    std::string                instance_prefix;
    int                        instance_line; // error reporting
    AutoPtr<Algorithm>         algo;
    std::vector<t_binding_nfo> bindings;
    bool                       autobind;
    std::unordered_map<std::string,std::string> boundinputs;
  } t_algo_nfo;

  /// \brief instanced algorithms
  std::unordered_map< std::string, t_algo_nfo > m_InstancedAlgorithms;

  /// \brief info about an instanced module
  typedef struct {
    std::string                module_name;
    std::string                instance_name;
    std::string                instance_prefix;
    int                        instance_line; // error reporting
    AutoPtr<Module>            mod;
    std::vector<t_binding_nfo> bindings;
    bool                       autobind;
  } t_module_nfo;

  /// \brief instanced modules
  std::unordered_map< std::string, t_module_nfo > m_InstancedModules;

  /// \brief stores info for single instructions
  class t_instr_nfo {
  public:
    antlr4::tree::ParseTree *instr = nullptr;
    int                       __id = -1;
    t_instr_nfo(antlr4::tree::ParseTree *instr_, int __id_) : instr(instr_), __id(__id_) {}
  };

  // forward definition
  class t_combinational_block;

  /// \brief subroutines
  class t_subroutine_nfo {
  public:
    std::string                                     name;
    t_combinational_block                          *top_block;
    std::unordered_set<std::string>                 allowed_reads;
    std::unordered_set<std::string>                 allowed_writes;
    std::unordered_map< std::string, std::string>   vios;  // [name in subroutine => var in host]
    std::vector<std::string>                        inputs;  // order list of input names
    std::vector<std::string>                        outputs; // order list of output names
  };
  std::unordered_map< std::string, t_subroutine_nfo* > m_Subroutines;

  /// \brief ending actions for blocks
  class t_end_action {
  public:
    virtual void getRefs(std::vector<size_t>& _refs) const = 0;
    virtual void getChildren(std::vector<t_combinational_block*>& _ch) const = 0;
  };

  /// \brief goto a next block at the end
  class end_action_goto_next : public t_end_action
  {
  public:
    t_combinational_block        *next;
    end_action_goto_next(t_combinational_block *next_) : next(next_) {}
    void getRefs(std::vector<size_t>& _refs) const override { _refs.push_back(next->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(next); }
  };

  /// \brief conditional branch at the end
  class end_action_if_else : public t_end_action
  {
  public:
    t_instr_nfo                   test;
    t_combinational_block        *if_next;
    t_combinational_block        *else_next;
    t_combinational_block        *after;
    end_action_if_else(t_instr_nfo test_, t_combinational_block *if_next_, t_combinational_block *else_next_, t_combinational_block *after_)
      : test(test_), if_next(if_next_), else_next(else_next_), after(after_) {}
    void getRefs(std::vector<size_t>& _refs) const override { _refs.push_back(if_next->id); _refs.push_back(else_next->id); _refs.push_back(after->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(if_next); _ch.push_back(else_next); _ch.push_back(after); }
  };

  /// \brief switch case at the end
  class end_action_switch_case : public t_end_action
  {
  public:
    t_instr_nfo                                                  test;
    std::vector<std::pair<std::string, t_combinational_block*> > case_blocks;
    t_combinational_block*                                       after;
    end_action_switch_case(t_instr_nfo test_, const std::vector<std::pair<std::string, t_combinational_block*> >& case_blocks_, t_combinational_block* after_)
      : test(test_), case_blocks(case_blocks_), after(after_) {}
    void getRefs(std::vector<size_t>& _refs) const override { for (auto b : case_blocks) { _refs.push_back(b.second->id); } _refs.push_back(after->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { for (auto b : case_blocks) { _ch.push_back(b.second); } _ch.push_back(after); }
  }; 

  /// \brief while loop at the end
  class end_action_while : public t_end_action
  {
  public:
    t_instr_nfo                   test;
    t_combinational_block        *iteration;
    t_combinational_block        *after;
    end_action_while(t_instr_nfo test_, t_combinational_block *iteration_, t_combinational_block *after_)
      : test(test_), iteration(iteration_), after(after_) {}
    void getRefs(std::vector<size_t>& _refs) const override { _refs.push_back(iteration->id); _refs.push_back(after->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(iteration);  _ch.push_back(after); }
  };

  /// \brief wait for algorithm termination at the end
  class end_action_wait : public t_end_action
  {
  public:
    int                           line;
    std::string                   algo_instance_name;
    t_combinational_block        *waiting;
    t_combinational_block        *next;
    end_action_wait(int line_, std::string algo_name_, t_combinational_block *waiting_, t_combinational_block *next_) : line(line_), algo_instance_name(algo_name_), waiting(waiting_), next(next_) {}
    void getRefs(std::vector<size_t>& _refs) const override { _refs.push_back(waiting->id); _refs.push_back(next->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(waiting); _ch.push_back(next); }
  };

  /// \brief return from a block at the end
  class end_action_return_from : public t_end_action
  {
  public:
    end_action_return_from() {  }
    void getRefs(std::vector<size_t>& _refs) const override {  }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override {  }
  };

  /// \brief goto next with return
  class end_action_goto_and_return_to : public t_end_action
  {
  public:
    t_combinational_block          *go_to;
    t_combinational_block          *return_to;
    end_action_goto_and_return_to(t_combinational_block* go_to_, t_combinational_block *return_to_) : go_to(go_to_), return_to(return_to_) {  }
    void getRefs(std::vector<size_t>& _refs) const override { _refs.push_back(go_to->id); _refs.push_back(return_to->id); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(go_to); _ch.push_back(return_to); }
  };

  /// \brief a combinational block of code
  class t_combinational_block
  {
  private:
    void swap_end(t_end_action *end) { if (end_action != nullptr) delete (end_action); end_action = end; }
  public:
    size_t                           id;                   // internal block id
    std::string                      block_name;           // internal block name (state name from source when applicable)
    bool                             is_state = false;     // true if block has to be a state, false otherwise
    bool                             no_skip = false;      // true the state cannot be skipped, even if empty
    int                              state_id = -1;        // state id, when assigned, -1 otherwise
    std::vector<t_instr_nfo>         instructions;         // list of instructions within block
    t_end_action                    *end_action = nullptr; // end action to perform
    t_subroutine_nfo                *subroutine = nullptr; // if block belongs to a subroutine
    std::unordered_set<std::string>  in_vars_read;         // which variables are read from before
    std::unordered_set<std::string>  out_vars_written;     // which variables have been written after
    ~t_combinational_block() { swap_end(nullptr); }

    void next(t_combinational_block *next)
    {
      // NOTE: nullptr is allowed due to forward refs
      swap_end(new end_action_goto_next(next));
    }
    const end_action_goto_next *next() const { return dynamic_cast<const end_action_goto_next*>(end_action); }

    void if_then_else(t_instr_nfo test, t_combinational_block *if_next, t_combinational_block *else_next, t_combinational_block *after)
    {
      swap_end(new end_action_if_else(test, if_next, else_next, after));
    }
    const end_action_if_else *if_then_else() const { return dynamic_cast<const end_action_if_else*>(end_action); }

    void switch_case(t_instr_nfo test, const std::vector<std::pair<std::string, t_combinational_block*> >& case_blocks, t_combinational_block* after)
    {
      swap_end(new end_action_switch_case(test, case_blocks, after));
    }
    const end_action_switch_case* switch_case() const { return dynamic_cast<const end_action_switch_case*>(end_action); }

    void wait(int line, std::string algo_name, t_combinational_block *waiting, t_combinational_block *next)
    {
      swap_end(new end_action_wait(line, algo_name, waiting, next));
    }
    const end_action_wait *wait() const { return dynamic_cast<const end_action_wait*>(end_action); }

    void while_loop(t_instr_nfo test, t_combinational_block *iteration, t_combinational_block *after)
    {
      swap_end(new end_action_while(test, iteration, after));
    }
    const end_action_while *while_loop() const { return dynamic_cast<const end_action_while*>(end_action); }

    void return_from()
    {
      swap_end(new end_action_return_from());
    }
    const end_action_return_from *return_from() const { return dynamic_cast<const end_action_return_from*>(end_action); }

    void goto_and_return_to(t_combinational_block* go_to,t_combinational_block *return_to)
    {
      swap_end(new end_action_goto_and_return_to(go_to, return_to));
    }
    const end_action_goto_and_return_to * goto_and_return_to() const { return dynamic_cast<const end_action_goto_and_return_to*>(end_action); }

    void getRefs(std::vector<size_t>& _refs) const { if (end_action != nullptr) end_action->getRefs(_refs); }
    void getChildren(std::vector<t_combinational_block*>& _ch) const { if (end_action != nullptr) end_action->getChildren(_ch); }
  };

  /// \brief context while gathering code
  typedef struct
  {
    int                    __id;
    t_combinational_block *break_to;
    // when in subroutine
    t_subroutine_nfo      *subroutine = nullptr;
  } t_gather_context;

  ///brief information about a forward jump
  typedef struct {
    t_combinational_block     *from;
    antlr4::ParserRuleContext *jump;
  } t_forward_jump;

  /// \brief always block
  t_combinational_block                                             m_Always;
  /// \brief all combinational blocks
  std::list< t_combinational_block* >                               m_Blocks;
  /// \brief state name to combination block
  std::unordered_map< std::string, t_combinational_block* >         m_State2Block;
  /// \brief id to combination block
  std::unordered_map< size_t, t_combinational_block* >              m_Id2Block;
  /// \brief stores encountered forwards refs for later resolution
  std::unordered_map< std::string, std::vector< t_forward_jump > >  m_JumpForwardRefs;
  /// \brief maximum state value of the algorithm
  int m_MaxState = -1;

public:

  virtual ~Algorithm()
  {
    // delete all blocks
    for (auto B : m_Blocks) {
      delete (B);
    }
    m_Blocks.clear();
    // delete all subroutines
    for (auto S : m_Subroutines) {
      delete (S.second);
    }
    m_Subroutines.clear();
  }

private:

  /// \brief returns true if belongs to inputs
  bool isInput(std::string var) const
  {
    return (m_InputNames.find(var) != m_InputNames.end());
  }

  /// \brief returns true if belongs to outputs
  bool isOutput(std::string var) const
  {
    return (m_OutputNames.find(var) != m_OutputNames.end());
  }

  /// \brief checks whether an identifier is an input or output
  bool isInputOrOutput(std::string var) const
  {
    return isInput(var) || isOutput(var);
  }

  /// \brief adds a combinational block to the list of blocks, performs book keeping
  template<class T_Block = t_combinational_block>
  t_combinational_block *addBlock(std::string name,int line=-1)
  {
    auto B = m_State2Block.find(name);
    if (B != m_State2Block.end()) {
      throw Fatal("state name '%s' already defined (line %d)",name.c_str(),line);
    }
    size_t next_id = m_Blocks.size();
    m_Blocks.emplace_back(new T_Block());
    m_Blocks.back()->block_name = name;
    m_Blocks.back()->id = next_id;
    m_Blocks.back()->end_action = nullptr;
    m_Id2Block[next_id] = m_Blocks.back();
    m_State2Block[name] = m_Blocks.back();
    return m_Blocks.back();
  }

  /// \brief splits a type between base type and width
  void splitType(std::string type, e_Type& _type, int& _width)
  {
    std::regex  rx_type("([[:alpha:]]+)([[:digit:]]+)");
    std::smatch sm_type;
    bool ok = std::regex_search(type, sm_type, rx_type);
    sl_assert(ok);
    // type
    if      (sm_type[1] == "int")  _type = Int;
    else if (sm_type[1] == "uint") _type = UInt;
    else sl_assert(false);
    // width
    _width = atoi(sm_type[2].str().c_str());
  }

  /// \brief splits a constant between width, base and value
  void splitConstant(std::string cst, int& _width, char& _base, std::string& _value, bool& _negative) const
  {
    std::regex  rx_type("(-?)([[:digit:]]+)([bdh])([[:digit:]a-fA-Fxz]+)");
    std::smatch sm_type;
    bool ok = std::regex_search(cst, sm_type, rx_type);
    sl_assert(ok);
    _width = atoi(sm_type[2].str().c_str());
    _base = sm_type[3].str()[0];
    _value = sm_type[4].str();
    _negative = !sm_type[1].str().empty();
  }

  /// \brief rewrites a constant
  std::string rewriteConstant(std::string cst) const
  {
    int width;
    std::string value;
    char base;
    bool negative;
    splitConstant(cst, width, base, value, negative);
    return (negative?"-":"") + std::to_string(width) + "'" + base + value;
  }

  /// \brief gather a value
  std::string gatherValue(siliceParser::ValueContext* ival)
  {
    if (ival->CONSTANT() != nullptr) {
      return rewriteConstant(ival->CONSTANT()->getText());
    } else if (ival->NUMBER() != nullptr) {
      return ival->NUMBER()->getText();
    } else {
      sl_assert(false);
    }
    return "";
  }

  /// \brief gather variable declaration
  void gatherDeclarationVar(siliceParser::DeclarationVarContext* decl)
  {
    t_var_nfo var;
    var.name = decl->IDENTIFIER()->getText();
    var.table_size = 0;
    splitType(decl->TYPE()->getText(), var.base_type, var.width);
    var.init_values.push_back("0");
    var.init_values[0] = gatherValue(decl->value());
    // verify the varaible does not shadow an input or output
    if (isInput(var.name)) {
      throw Fatal("variable '%s' is shadowing input of same name (line %d)", var.name.c_str(), decl->getStart()->getLine());
    } else if (isOutput(var.name)) {
      throw Fatal("variable '%s' is shadowing output of same name (line %d)", var.name.c_str(), decl->getStart()->getLine());
    }
    // ok!
    m_Vars.emplace_back(var);
    m_VarNames.insert(std::make_pair(var.name,(int)m_Vars.size()-1));
  }

  /// \brief gather all values from an init list
  void gatherInitList(siliceParser::InitListContext* ilist, std::vector<std::string>& _values_str)
  {
    for (auto i : ilist->value()) {
      _values_str.push_back(gatherValue(i));
    }
  }

  /// \brief gather variable declaration
  void gatherDeclarationTable(siliceParser::DeclarationTableContext* decl)
  {
    t_var_nfo var;
    var.name = decl->IDENTIFIER()->getText();
    splitType(decl->TYPE()->getText(), var.base_type, var.width);
    if (decl->NUMBER() != nullptr) {
      var.table_size = atoi(decl->NUMBER()->getText().c_str());
      if (var.table_size <= 0) {
        throw Fatal("table has zero or negative size (line %d)",decl->getStart()->getLine());
      }
      var.init_values.resize(var.table_size, "0");
    } else {
      var.table_size = 0; // autosize from init
    }
    // read init list
    std::vector<std::string> values_str;
    if (decl->initList() != nullptr) {
      gatherInitList(decl->initList(), values_str);
    } else {
      std::string initstr = decl->STRING()->getText();
      initstr = initstr.substr(1, initstr.length() - 2); // remove '"' and '"'
      values_str.resize(initstr.length()+1/*null terminated*/);
      ForIndex(i, (int)initstr.length()) {
        values_str[i] = std::to_string((int)(initstr[i]));
      }
      values_str.back() = "0"; // null terminated
    }
    if (var.table_size == 0) { // autosize
      var.table_size = (int)values_str.size();
      var.init_values.resize(var.table_size, "0");
    } else if (values_str.empty()) {
      // this is ok: auto init to zero
    } else if (values_str.size() != var.table_size) {
      throw Fatal("incorrect number of values in table initialization (line %d)",decl->getStart()->getLine());
    }
    ForIndex(i, values_str.size()) {
      if (values_str[i].find_first_of("hbd") != std::string::npos) {
        var.init_values[i] = rewriteConstant(values_str[i]);
      } else {
        var.init_values[i] = values_str[i];
      }     
    }
    m_Vars.emplace_back(var);
    m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
  }

  /// \brief extract the list of bindings
  void getBindings(
    siliceParser::ModalgBindingListContext *bindings,
    std::vector<t_binding_nfo>& _vec_bindings,
    bool& _autobind) const
  {
    if (bindings == nullptr) return;
    while (bindings != nullptr) {
      if (bindings->modalgBinding() != nullptr) {
        if (bindings->modalgBinding()->AUTO() != nullptr) {
          _autobind = true;
        } else {
          t_binding_nfo nfo;          
          nfo.line  = -1;
          nfo.left  = bindings->modalgBinding()->left->getText();
          nfo.right = bindings->modalgBinding()->right->getText();
          nfo.line  = (int)bindings->modalgBinding()->getStart()->getLine();
          if (bindings->modalgBinding()->LDEFINE() != nullptr) {
            nfo.dir = e_Left;           
          } else if (bindings->modalgBinding()->RDEFINE() != nullptr) {
            nfo.dir = e_Right;
          } else {
            sl_assert(bindings->modalgBinding()->BDEFINE() != nullptr);
            nfo.dir = e_BiDir;
          }
          _vec_bindings.push_back(nfo);
        }
      }
      bindings = bindings->modalgBindingList();
    }
  }

  /// \brief gather algorithm declaration
  void gatherDeclarationAlgo(siliceParser::DeclarationModAlgContext* alg)
  {
    t_algo_nfo nfo;
    nfo.algo_name       = alg->modalg->getText();
    nfo.instance_name   = alg->name->getText();
    nfo.instance_clock  = m_Clock;
    nfo.instance_reset  = m_Reset;
    if (alg->algModifiers() != nullptr) {
      for (auto m : alg->algModifiers()->algModifier()) {
        if (m->sclock() != nullptr) {
          nfo.instance_clock = m->sclock()->IDENTIFIER()->getText();
        }
        if (m->sreset() != nullptr) {
          nfo.instance_reset = m->sreset()->IDENTIFIER()->getText();
        }
        if (m->sautorun() != nullptr) {
          throw Fatal("autorun not allowed when instantiating algorithms (line %d)", m->sautorun()->getStart()->getLine());
        }
      }
    }
    nfo.instance_prefix = "_" + alg->name->getText();
    nfo.instance_line = (int)alg->getStart()->getLine();
    if (m_InstancedAlgorithms.find(nfo.instance_name) != m_InstancedAlgorithms.end()) {
      throw Fatal("an algorithm was already instantiated with the same name (line %d)", alg->name->getLine());
    }
    nfo.autobind = false;
    getBindings(alg->modalgBindingList(), nfo.bindings, nfo.autobind);
    m_InstancedAlgorithms[nfo.instance_name] = nfo;
  }

  /// \brief gather module declaration
  void gatherDeclarationModule(siliceParser::DeclarationModAlgContext* mod)
  {
    t_module_nfo nfo;
    nfo.module_name = mod->modalg->getText();
    nfo.instance_name = mod->name->getText();
    nfo.instance_prefix = "_" + mod->name->getText();
    nfo.instance_line = (int)mod->getStart()->getLine();
    if (m_InstancedModules.find(nfo.instance_name) != m_InstancedModules.end()) {
      throw Fatal("a module was already instantiated with the same name (line %d)", mod->name->getLine());
    }
    nfo.autobind = false;
    getBindings(mod->modalgBindingList(), nfo.bindings, nfo.autobind);
    m_InstancedModules[nfo.instance_name] = nfo;
  }

  /// \brief returns the rewritten indentifier, taking into account bindings, inputs/outputs, custom clocks and resets
  std::string rewriteIdentifier(std::string prefix, std::string var,const t_subroutine_nfo *sub,size_t line = 0, std::string ff = FF_D) const
  {
    if (var == ALG_RESET || var == ALG_CLOCK) {
      return var;
    } else if (var == m_Reset) { // cannot be ALG_RESET
      if (m_VIOBoundToModAlgOutputs.find(var) == m_VIOBoundToModAlgOutputs.end()) {
        throw Fatal("custom reset signal has to be bound to a module output (line %d)",line);
      }
      return m_VIOBoundToModAlgOutputs.at(var);
    } else if (var == m_Clock) { // cannot be ALG_CLOCK
      if (m_VIOBoundToModAlgOutputs.find(var) == m_VIOBoundToModAlgOutputs.end()) {
        throw Fatal("custom clock signal has to be bound to a module output (line %d)", line);
      }
      return m_VIOBoundToModAlgOutputs.at(var);
    } else if (isInput(var)) {
      return ALG_INPUT + prefix + var;
    } else if (isOutput(var)) {
      auto usage = m_Outputs.at(m_OutputNames.at(var)).usage;
      if (usage == e_FlipFlop) {
        return ff + prefix + var;
      } else if (usage == e_Bound) {
        return m_VIOBoundToModAlgOutputs.at(var);
      } else {
        // should be e_Assigned ; currently replaced by a flip-flop but could be avoided
        throw Fatal("assigned outputs: not yet implemented");
      }
    } else {
      auto V = m_VarNames.find(var);
      if (V == m_VarNames.end()) {
        // if in subroutine, check for inputs, outputs
        if (sub != nullptr) {
          auto Vsub = sub->vios.find(var);
          if (Vsub == sub->vios.end()) {
            throw Fatal("variable '%s' was never declared (line %d)", var.c_str(), line);
          } else {
            return ff + prefix + Vsub->second;
          }
        } else {
          throw Fatal("variable '%s' was never declared (line %d)", var.c_str(), line);
        }
      }
      if (m_Vars.at(V->second).usage == e_Bound) {
        // bound to an input/output
        return m_VIOBoundToModAlgOutputs.at(var);
      } else {
        // flip-flop
        return ff + prefix + var;
      }
    }
  }

  /// \brief rewrite an expression, renaming identifiers
  std::string rewriteExpression(std::string prefix, antlr4::tree::ParseTree *expr, int __id, const t_subroutine_nfo* sub) const
  {
    std::string result;
    if (expr->children.empty()) {
      auto term = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
      if (term) {
        if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
          return rewriteIdentifier(prefix, expr->getText(), sub, term->getSymbol()->getLine());
        } else if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
          return rewriteConstant(expr->getText());
        } else if (term->getSymbol()->getType() == siliceParser::REPEATID) {
          if (__id == -1) {
            throw Fatal("__id used outside of repeat block (line %d)", term->getSymbol()->getLine());
          }
          return std::to_string(__id);
        } else {
          return expr->getText();
        }
      } else {
        return expr->getText();
      }
    } else {
      auto access = dynamic_cast<siliceParser::AccessContext*>(expr);
      if (access) {
        std::ostringstream ostr;
        writeAccess(prefix, ostr, false, access, __id, sub);
        result = result + ostr.str();
      } else {
        // recurse
        for (auto c : expr->children) {
          result = result + rewriteExpression(prefix, c, __id, sub);
        }
      }
    }
    return result;
  }

  /// \brief integer name of the next block
  int m_NextBlockName = 1;
  /// \brief resets the block name generator
  void resetBlockName()
  {
    m_NextBlockName = 1;
  }
  /// \brief generate the next block name
  std::string generateBlockName()
  {
    return "__block_" + std::to_string(m_NextBlockName++);
  }

  /// \brief update current block based on the next instruction list
  t_combinational_block *updateBlock(siliceParser::InstructionListContext* ilist, t_combinational_block *_current, t_gather_context *_context)
  {
    if (ilist->state() != nullptr) {
      // start a new block
      std::string name = "++";
      if (ilist->state()->state_name != nullptr) {
        name = ilist->state()->state_name->getText();
      }
      bool no_skip = false;
      if (name == "++") {
        name = generateBlockName();
        no_skip = true;
      }
      t_combinational_block *block = addBlock(name,(int)ilist->state()->getStart()->getLine());
      block->is_state = true; // block explicitely required to be a state
      block->no_skip = no_skip;
      _current->next(block);
      return block;
    } else {
      return _current;
    }
  }

  /// \brief gather a break from loop
  t_combinational_block *gatherBreakLoop(siliceParser::BreakLoopContext* brk, t_combinational_block *_current, t_gather_context *_context)
  {
    // current goes to after while
    if (_context->break_to == nullptr) {
      throw Fatal("cannot break outside of a loop (line %d)", brk->getStart()->getLine());
    }
    _current->next(_context->break_to);
    _context->break_to->is_state = true;
    // start a new block after the break
    t_combinational_block *block = addBlock(generateBlockName());
    // return block
    return block;
  }

  /// \brief gather a while block
  t_combinational_block *gatherWhile(siliceParser::WhileLoopContext* loop, t_combinational_block *_current, t_gather_context *_context)
  {
    // while header block
    t_combinational_block *while_header = addBlock("__while" + generateBlockName());
    _current->next(while_header);
    // iteration block
    t_combinational_block *iter = addBlock(generateBlockName());
    // block for after the while
    t_combinational_block *after = addBlock(generateBlockName());
    // parse the iteration block
    t_combinational_block *previous  = _context->break_to;
    _context->break_to               = after;
    t_combinational_block *iter_last = gather(loop->while_block, iter, _context);
    _context->break_to               = previous;
    // after iteration go back to header
    iter_last->next(while_header);
    // add while to header
    while_header->while_loop(t_instr_nfo(loop->expression_0(), _context->__id), iter, after);
    // set states
    while_header->is_state = true; // header has to be a state
    after       ->is_state = true; // after has to be a state
    return after;
  }

  /// \brief gather a subroutine
  t_combinational_block *gatherSubroutine(siliceParser::SubroutineContext* sub, t_combinational_block *_current, t_gather_context *_context)
  {
    t_subroutine_nfo *nfo = new t_subroutine_nfo;
    // subroutine name
    nfo->name = sub->IDENTIFIER()->getText();
    // subroutine block
    t_combinational_block *subb = addBlock("__sub_" + nfo->name,(int)sub->getStart()->getLine());
    // cross ref between block and subroutine
    subb->subroutine = nfo;
    nfo ->top_block  = subb;
    // gather inputs/outputs and access constraints
    sl_assert(sub->subroutineParamList() != nullptr);
    // constraint?
    for (auto P : sub->subroutineParamList()->subroutineParam()) {
      if (P->READ() != nullptr) {
        nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
      } else if (P->WRITE() != nullptr) {
        nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      } else if (P->READWRITE() != nullptr) {
        nfo->allowed_reads.insert(P->IDENTIFIER()->getText());
        nfo->allowed_writes.insert(P->IDENTIFIER()->getText());
      }
      // input or output?
      if (P->input() != nullptr || P->output() != nullptr) {
        std::string in_or_out;
        std::string ioname;
        std::string strtype;
        int tbl_size = 0;
        if (P->input() != nullptr) {
          in_or_out = "i";
          ioname  = P->input()->IDENTIFIER()->getText();
          strtype = P->input()->TYPE()->getText();
          if (P->input()->NUMBER() != nullptr) {
            tbl_size = atoi(P->input()->NUMBER()->getText().c_str());
          }
          nfo->inputs.push_back(ioname);
        } else {
          in_or_out = "o";
          ioname = P->output()->IDENTIFIER()->getText();
          strtype = P->output()->TYPE()->getText();
          if (P->output()->NUMBER() != nullptr) {
            tbl_size = atoi(P->output()->NUMBER()->getText().c_str());
          }
          nfo->outputs.push_back(ioname);
        }
        // check for name collisions
        if ( m_InputNames .count(ioname) > 0
          || m_OutputNames.count(ioname) > 0
          || m_VarNames   .count(ioname) > 0
          || ioname == m_Clock || ioname == m_Reset) {
          throw Fatal("subroutine '%s' input/output '%s' is using the same name as a host VIO, clock or reset (line %d)",
            nfo->name.c_str(),ioname.c_str(),sub->getStart()->getLine());
        }
        // insert variable in host for each input/output
        t_var_nfo var;
        var.name = in_or_out + "_" + nfo->name  + "_" + ioname;
        var.table_size = tbl_size;
        splitType(strtype, var.base_type, var.width);
        var.init_values.resize(max(var.table_size, 1), "0");
        m_Vars.emplace_back(var);
        m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
        nfo->vios.insert(std::make_pair(ioname,var.name));
      }
    }
    // parse the subroutine
    _context->subroutine = nfo;
    t_combinational_block *sub_last = gather(sub->instructionList(), subb, _context);
    _context->subroutine = nullptr;
    // add return from last
    sub_last->return_from();
    // subroutine has to be a state
    subb ->is_state = true;
    // record as a know subroutine
    m_Subroutines.insert(std::make_pair(nfo->name,nfo));
    // keep going with current
    return _current;
  }

  /// \brief gather a jump
  t_combinational_block* gatherJump(siliceParser::JumpContext* jump, t_combinational_block* _current, t_gather_context* _context)
  {
    std::string name = jump->IDENTIFIER()->getText();
    auto B = m_State2Block.find(name);
    if (B == m_State2Block.end()) {
      // forward reference
      _current->next(nullptr);
      t_forward_jump j;
      j.from = _current;
      j.jump = jump;
      m_JumpForwardRefs[name].push_back(j);
    } else {
      _current->next(B->second);
      B->second->is_state = true; // destination has to be a state
    }
    // start a new block just after the jump
    t_combinational_block* after = addBlock(generateBlockName());
    // return block after jump
    return after;
  }

  /// \brief gather a call
  t_combinational_block *gatherCall(siliceParser::CallContext* call, t_combinational_block *_current, t_gather_context *_context)
  {
    // start a new block just after the call
    t_combinational_block* after = addBlock(generateBlockName());
    // has to be a state to return to
    after->is_state = true;
    // find the destination
    std::string name = call->IDENTIFIER()->getText();
    auto B = m_State2Block.find(name);
    if (B == m_State2Block.end()) {
      // forward reference
      _current->goto_and_return_to(nullptr, after);
      t_forward_jump j;
      j.from = _current;
      j.jump = call;
      m_JumpForwardRefs[name].push_back(j);
    } else {
      // current goes there and return on next
      _current->goto_and_return_to(B->second, after);
      B->second->is_state = true; // destination has to be a state
    }
    // return block after call
    return after;
  }

  /// \brief gather a return
  t_combinational_block* gatherReturnFrom(siliceParser::ReturnFromContext* ret, t_combinational_block* _current, t_gather_context* _context)
  {
    // add return at end of current
    _current->return_from();
    // start a new block
    t_combinational_block* block = addBlock(generateBlockName());
    return block;
  }

  /// \brief gather a synchronous execution
  t_combinational_block* gatherSyncExec(siliceParser::SyncExecContext* sync, t_combinational_block* _current, t_gather_context* _context)
  {
    // add sync as instruction, will perform the call
    _current->instructions.push_back(t_instr_nfo(sync, _context->__id));
    // are we calling a subroutine?
    auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
    if (S != m_Subroutines.end()) {
      // yes! create a new block, call subroutine
      t_combinational_block* after = addBlock(generateBlockName());
      // has to be a state to return to
      after->is_state = true;
      // call subroutine
      _current->goto_and_return_to(S->second->top_block, after);
      // after is new current
      _current = after;
    }
    // gather the join exec, will perform the readback
    _current = gather(sync->joinExec(), _current, _context);
    return _current;
  }
  /// \brief gather a join execution
  t_combinational_block *gatherJoinExec(siliceParser::JoinExecContext* join, t_combinational_block *_current, t_gather_context *_context)
  {
    // are we calling a subroutine?
    auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
    if (S == m_Subroutines.end()) { // no, waiting for algorithm
      // block for the wait
      t_combinational_block* waiting_block = addBlock(generateBlockName());
      waiting_block->is_state = true; // state for waiting
      // enter wait after current
      _current->next(waiting_block);
      // block for after the wait
      t_combinational_block* next_block = addBlock(generateBlockName());
      next_block->is_state = true; // state to goto after the wait
      // ask current block to wait the algorithm termination
      waiting_block->wait((int)join->getStart()->getLine(), join->IDENTIFIER()->getText(), waiting_block, next_block);
      // first instruction in next block will read result
      next_block->instructions.push_back(t_instr_nfo(join, _context->__id));
      // use this next block now
      return next_block;
    } else {
      // subroutine, simply readback results
      _current->instructions.push_back(t_instr_nfo(join, _context->__id));
      return _current;
    }
  }

  /// \brief tests whether a graph of block is stateless
  bool isStateLessGraph(t_combinational_block *head) const
  {
    std::queue< t_combinational_block* > q;
    q.push(head);
    while (!q.empty()) {
      auto cur = q.front();
      q.pop();
      // test
      if (cur == nullptr) { // tags a forward ref (jump), not stateless
        return false;
      }
      if (cur->is_state) {
        return false; // not stateless
      }
      // recurse
      std::vector< t_combinational_block* > children;
      cur->getChildren(children);
      for (auto c : children) {
        q.push(c);
      }
    }
    return true;
  }

  /// \brief gather an if-then-else
  t_combinational_block *gatherIfElse(siliceParser::IfThenElseContext* ifelse, t_combinational_block *_current, t_gather_context *_context)
  {
    t_combinational_block *if_block   = addBlock(generateBlockName());
    t_combinational_block *else_block = addBlock(generateBlockName());
    // parse the blocks
    t_combinational_block *if_block_after   = gather(ifelse->if_block, if_block, _context);
    t_combinational_block *else_block_after = gather(ifelse->else_block, else_block, _context);
    // create a block for after the if-then-else
    t_combinational_block *after = addBlock(generateBlockName());
    if_block_after  ->next(after);
    else_block_after->next(after);
    // add if_then_else to current
    _current->if_then_else(t_instr_nfo(ifelse->expression_0(), _context->__id), if_block, else_block, after);
    // checks whether after has to be a state
    after->is_state = !isStateLessGraph(if_block) || !isStateLessGraph(else_block);
    return after;
  }

  /// \brief gather an if-then
  t_combinational_block *gatherIfThen(siliceParser::IfThenContext* ifthen, t_combinational_block *_current, t_gather_context *_context)
  {
    t_combinational_block *if_block   = addBlock(generateBlockName());
    t_combinational_block *else_block = addBlock(generateBlockName());
    // parse the blocks
    t_combinational_block *if_block_after = gather(ifthen->if_block, if_block, _context);
    // create a block for after the if-then-else
    t_combinational_block *after = addBlock(generateBlockName());
    if_block_after->next(after);
    else_block    ->next(after);
    // add if_then_else to current
    _current->if_then_else(t_instr_nfo(ifthen->expression_0(), _context->__id), if_block, else_block, after);
    // checks whether after has to be a state
    after->is_state = !isStateLessGraph(if_block);
    return after;
  }

  /// \brief gather a switch-case
  t_combinational_block* gatherSwitchCase(siliceParser::SwitchCaseContext* switchCase, t_combinational_block* _current, t_gather_context* _context)
  {
    // create a block for after the switch-case
    t_combinational_block* after = addBlock(generateBlockName());
    // create a block per case statement
    std::vector<std::pair<std::string,t_combinational_block*> > case_blocks;
    for (auto cb : switchCase->caseBlock()) {
      t_combinational_block* case_block       = addBlock(generateBlockName() + "_case");
      std::string            value            = "default";
      if (cb->case_value != nullptr) {
        value = gatherValue(cb->case_value);
      }
      case_blocks.push_back(std::make_pair(value,case_block));
      t_combinational_block* case_block_after = gather(cb->case_block, case_block, _context);
      case_block_after->next(after);
    }    
    // add switch-case to current
    _current->switch_case(t_instr_nfo(switchCase->expression_0(), _context->__id), case_blocks, after);
    // checks whether after has to be a state
    bool is_state = false;
    for (auto b : case_blocks) {
      is_state = is_state || !isStateLessGraph(b.second);
    }
    after->is_state = is_state;
    return after;
  }

  /// \brief gather a repeat block
  t_combinational_block *gatherRepeatBlock(siliceParser::RepeatBlockContext* repeat, t_combinational_block *_current, t_gather_context *_context)
  {
    if (_context->__id != -1) {
      throw Fatal("repeat blocks cannot be nested (line %d)",repeat->getStart()->getLine());
    } else {
      std::string rcnt = repeat->REPEATCNT()->getText();
      int num = atoi(rcnt.substr(0, rcnt.length()-1).c_str());
      ForIndex(id, num) {
        _context->__id = id;
        _current = gather(repeat->instructionList(), _current, _context);
      }
      _context->__id = -1;
    }
    return _current;
  }

  /// \brief gather always assigned
  void gatherAlwaysAssigned(siliceParser::AlwaysAssignedListContext* alws)
  {
    while (alws) {
      auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(alws->alwaysAssigned());
      if (alw) {
        m_Always.instructions.push_back(t_instr_nfo(alw, -1));
        // check for double flip-flop
        if (alw->ALWSASSIGNDBL() != nullptr) {
          // insert temporary variable
          t_var_nfo var;
          var.name = "delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
          std::pair<e_Type,int> type_width = determineAccessTypeAndWidth(alw->access(), alw->IDENTIFIER());
          var.table_size = 0;
          var.base_type = type_width.first;
          var.width = type_width.second;
          var.init_values.push_back("0");
          m_Vars.emplace_back(var);
          m_VarNames.insert(std::make_pair(var.name, (int)m_Vars.size() - 1));
        }
      }
      alws = alws->alwaysAssignedList();
    }
  }

  /// \brief check the access permissions on assignements
  void checkAssignPermissions(siliceParser::AssignmentContext *assign, t_gather_context *_context)
  {
    // in subroutine
    if (_context->subroutine == nullptr) {
      return; // no, return, no checks required
    }
    // yes: go ahead with checks
    std::unordered_set<std::string> read, written;
    determineVIOAccess(assign, m_VarNames,    nullptr, read, written);
    determineVIOAccess(assign, m_OutputNames, nullptr, read, written);
    determineVIOAccess(assign, m_InputNames,  nullptr, read, written);
    // now verify all permissions are granted
    for (auto R : read) {
      if (_context->subroutine->allowed_reads.count(R) == 0) {
        throw Fatal("variable '%s' is read by subroutine without explicit permission (line %d)",R.c_str(),assign->getStart()->getLine());
      }
    }
    for (auto W : written) {
      if (_context->subroutine->allowed_writes.count(W) == 0) {
        throw Fatal("variable '%s' is written by subroutine without explicit permission (line %d)", W.c_str(), assign->getStart()->getLine());
      }
    }
  }

  /// \brief sematic parsing, first discovery pass
  t_combinational_block *gather(antlr4::tree::ParseTree *tree, t_combinational_block *_current, t_gather_context *_context)
  {
    if (tree == nullptr) {
      return _current;
    }

    auto declvar = dynamic_cast<siliceParser::DeclarationVarContext*>(tree);
    auto decltbl = dynamic_cast<siliceParser::DeclarationTableContext*>(tree);
    auto always  = dynamic_cast<siliceParser::AlwaysAssignedListContext*>(tree);
    auto ilist   = dynamic_cast<siliceParser::InstructionListContext*>(tree);
    auto ifelse  = dynamic_cast<siliceParser::IfThenElseContext*>(tree);
    auto ifthen  = dynamic_cast<siliceParser::IfThenContext*>(tree);
    auto switchC = dynamic_cast<siliceParser::SwitchCaseContext*>(tree);
    auto loop    = dynamic_cast<siliceParser::WhileLoopContext*>(tree);
    auto jump    = dynamic_cast<siliceParser::JumpContext*>(tree);
    auto modalg  = dynamic_cast<siliceParser::DeclarationModAlgContext*>(tree);
    auto assign  = dynamic_cast<siliceParser::AssignmentContext*>(tree);
    auto display = dynamic_cast<siliceParser::DisplayContext *>(tree);
    auto async   = dynamic_cast<siliceParser::AsyncExecContext*>(tree);
    auto join    = dynamic_cast<siliceParser::JoinExecContext*>(tree);
    auto sync    = dynamic_cast<siliceParser::SyncExecContext*>(tree);
    auto repeat  = dynamic_cast<siliceParser::RepeatBlockContext*>(tree);
    auto sub     = dynamic_cast<siliceParser::SubroutineContext*>(tree);
    auto call    = dynamic_cast<siliceParser::CallContext*>(tree);
    auto ret     = dynamic_cast<siliceParser::ReturnFromContext*>(tree);
    auto breakL  = dynamic_cast<siliceParser::BreakLoopContext*>(tree);

    bool recurse = true;

    if      (declvar) { gatherDeclarationVar(declvar); } 
    else if (decltbl) { gatherDeclarationTable(decltbl); } 
    else if (modalg)  {
      std::string name = modalg->modalg->getText();      
      if (m_KnownModules.find(name) != m_KnownModules.end()) {
        gatherDeclarationModule(modalg);
      } else {
        gatherDeclarationAlgo(modalg);
      }
    }
    else if (ifelse)  { _current = gatherIfElse(ifelse, _current, _context);      recurse = false; }
    else if (ifthen)  { _current = gatherIfThen(ifthen, _current, _context);      recurse = false; }
    else if (switchC) { _current = gatherSwitchCase(switchC, _current, _context); recurse = false; }
    else if (loop)    { _current = gatherWhile(loop, _current, _context);         recurse = false; }
    else if (always)  { gatherAlwaysAssigned(always);                             recurse = false; }
    else if (repeat)  { _current = gatherRepeatBlock(repeat, _current, _context); recurse = false; } 
    else if (sub)     { _current = gatherSubroutine(sub, _current, _context);     recurse = false; }
    else if (sync)    { _current = gatherSyncExec(sync, _current, _context);      recurse = false; }
    else if (async)   { _current->instructions.push_back(t_instr_nfo(async, _context->__id)); }
    else if (call)    { _current = gatherCall(call, _current, _context); }
    else if (jump)    { _current = gatherJump(jump, _current, _context); }
    else if (ret)     { _current = gatherReturnFrom(ret, _current, _context); }
    else if (breakL)  { _current = gatherBreakLoop(breakL, _current, _context); }
    else if (join)    { _current = gatherJoinExec(join, _current, _context); }
    else if (assign)  { checkAssignPermissions(assign,_context);  _current->instructions.push_back(t_instr_nfo(assign, _context->__id)); }
    else if (display) { _current->instructions.push_back(t_instr_nfo(display, _context->__id)); }
    else if (ilist)   { _current = updateBlock(ilist, _current, _context); }

    // recurse
    if (recurse) {
      for (const auto& c : tree->children) {
        _current = gather(c, _current, _context);
      }
    }

    return _current;
  }

  /// \brief resolves forward references for jumps
  void resolveForwardJumpRefs()
  {
    for (auto& refs : m_JumpForwardRefs) {
      // get block by name
      auto B = m_State2Block.find(refs.first);
      if (B == m_State2Block.end()) {
        std::string lines;
        sl_assert(!refs.second.empty());
        for (const auto& j : refs.second) {
          lines += std::to_string(j.jump->getStart()->getLine()) + ",";
        }
        lines.pop_back(); // remove last comma
        std::string msg = "cannot find state '"
          + refs.first + "' (line"
          + (refs.second.size() > 1 ? "s " : " ")
          + lines + ")";
        throw Fatal("%s",msg.c_str());
      } else {
        for (auto& j : refs.second) {
          if (dynamic_cast<siliceParser::JumpContext*>(j.jump)) {
            // update jump
            j.from->next(B->second);
          } else if (dynamic_cast<siliceParser::CallContext*>(j.jump)) {
            // update call
            const end_action_goto_and_return_to* gaf = j.from->goto_and_return_to();
            j.from->goto_and_return_to(B->second,gaf->return_to);
          } else {
            sl_assert(false);
          }
          B->second->is_state = true; // destination has to be a state
        }
      }
    }
  }

  /// \brief generates the states for the entire algorithm
  void generateStates()
  {
    m_MaxState = 0;
    std::unordered_set< t_combinational_block* > visited;
    std::queue< t_combinational_block* > q;
    q.push(m_Blocks.front()); // start from main
    while (!q.empty()) {
      auto cur = q.front();
      q.pop();
      // test
      if (cur->is_state) {
        sl_assert(cur->state_id == -1);
        cur->state_id = m_MaxState++;
      }
      // recurse
      std::vector< t_combinational_block* > children;
      cur->getChildren(children);
      for (auto c : children) {
        if (visited.find(c) == visited.end()) {
          visited.insert(c);
          q.push(c);
        }
      }
    }
    // additional internal state
    m_MaxState++;
    // report
    std::cerr << "algorithm " << m_Name << " num states: " << m_MaxState << std::endl;
  }

  /// \brief returns the max state value of the algorithm
  int maxState() const
  {
    return m_MaxState;
  }

  /// \brief returns the index to jump to to intitate the termination sequence
  int terminationState() const
  {
    return m_MaxState - 1;
  }

  /// \brief returns the state bit-width for the algorithm
  int stateWidth() const
  {
    int max_s = maxState();
    int w = 0;
    while (max_s > (1 << w)) {
      w++;
    }
    return w;
  }

  /// \brief fast-forward to the next non empty state
  const t_combinational_block *fastForward(const t_combinational_block *block) const
  {
    sl_assert(block->is_state);
    const t_combinational_block *current = block;
    const t_combinational_block *last_state = block;
    while (true) {
      if (current->no_skip) {
        // no skip, stop here
        return last_state;
      }
      if (!current->instructions.empty()) {
        // non-empty, stop here
        return last_state;
      }
      if (current->next() == nullptr) {
        // not a simple jump, stop here
        return last_state;
      } else {
        current = current->next()->next;
      }
      if (current->is_state) {
        last_state = current;
      }
    }
    // never reached
    return nullptr;
  }

  /// \brief gather inputs and outputs
  void gatherIOs(siliceParser::InOutListContext *inout)
  {
    if (inout == nullptr) {
      return;
    }
    for (auto io : inout->inOrOut()) {
      auto input  = dynamic_cast<siliceParser::InputContext*>(io->input());
      auto output = dynamic_cast<siliceParser::OutputContext*>(io->output());
      auto inout  = dynamic_cast<siliceParser::InoutContext*>(io->inout());
      if (input) {
        t_inout_nfo io;
        io.name = input->IDENTIFIER()->getText();
        io.table_size = 0;
        splitType(input->TYPE()->getText(), io.base_type, io.width);
        if (input->NUMBER() != nullptr) {
          io.table_size = atoi(input->NUMBER()->getText().c_str());
        }
        io.init_values.resize(max(io.table_size, 1), "0");
        m_Inputs .emplace_back(io);
        m_InputNames.insert(make_pair(io.name, (int)m_Inputs.size() - 1));
      } else if (output) {
        t_inout_nfo io;
        io.name = output->IDENTIFIER()->getText();
        io.table_size = 0;
        splitType(output->TYPE()->getText(), io.base_type, io.width);
        if (output->NUMBER() != nullptr) {
          io.table_size = atoi(output->NUMBER()->getText().c_str());
        }
        io.init_values.resize(max(io.table_size, 1), "0");
        m_Outputs.emplace_back(io);
        m_OutputNames.insert(make_pair(io.name, (int)m_Outputs.size() - 1));
      } else if (inout) {
        t_inout_nfo io;
        io.name = inout->IDENTIFIER()->getText();
        io.table_size = 0;
        splitType(inout->TYPE()->getText(), io.base_type, io.width);
        if (inout->NUMBER() != nullptr) {
          io.table_size = atoi(inout->NUMBER()->getText().c_str());
        }
        io.init_values.resize(max(io.table_size, 1), "0");
        m_InOuts.emplace_back(io);
        m_InOutNames.insert(make_pair(io.name, (int)m_InOuts.size() - 1));
      } else {
        // symbol, ignore
      }
    }
  }

  /// \brief extract the ordered list of parameters
  void getParams(siliceParser::ParamListContext *params, std::vector<std::string>& _vec_params, const t_subroutine_nfo *sub) const
  {
    if (params == nullptr) return;
    while (params->IDENTIFIER() != nullptr) {
      std::string var = params->IDENTIFIER()->getText();
      if (sub) { // if in subroutine overwrite variable names
        auto V = sub->vios.find(var);
        if (V != sub->vios.end()) {
          var = V->second;
        }
      }
      _vec_params.push_back(var);
      params = params->paramList();
      if (params == nullptr) return;
    }
  }

private:

  /// \brief writes a call to an algorithm
  void writeAlgorithmCall(std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::ParamListContext* plist, const t_subroutine_nfo* sub) const
  {
    std::vector<std::string> params;
    getParams(plist, params, sub);
    // if params are empty we simply call, otherwise we set the inputs
    if (!params.empty()) {
      if (a.algo->m_Inputs.size() != params.size()) {
        throw Fatal("incorrect number of input parameters in call to algorithm instance '%s' (line %d)", 
          a.instance_name.c_str(), plist->getStart()->getLine());
      }
      // set inputs
      int p = 0;
      for (const auto& ins : a.algo->m_Inputs) {
        if (a.boundinputs.count(ins.name) > 0) {
          throw Fatal("algorithm instance '%s' cannot be called as its input '%s' is bound (line %d)", 
            a.instance_name.c_str(), ins.name.c_str(), plist->getStart()->getLine());
        }
        out << FF_D << a.instance_prefix << "_" << ins.name << " = " << rewriteIdentifier(prefix, params[p++], sub) << ";" << std::endl;
      }
    }
    // restart algorithm (pulse run low)
    out << a.instance_prefix << "_" << ALG_RUN << " = 0;" << std::endl;
  }

  /// \brief writes reading back the results of an algorithm
  void writeAlgorithmReadback(std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::ParamListContext* plist, const t_subroutine_nfo* sub) const
  {
    std::vector<std::string> params;
    getParams(plist, params, sub);
    // if params are empty we simply wait, otherwise we set the outputs
    if (!params.empty()) {
      if (a.algo->m_Outputs.size() != params.size()) {
        throw Fatal("incorrect number of output parameters reading back result from algorithm instance '%s' (line %d)",
          a.instance_name.c_str(), plist->getStart()->getLine());
      }
      // read outputs
      int p = 0;
      for (const auto& outs : a.algo->m_Outputs) {
        out << rewriteIdentifier(prefix, params[p++], sub) << " = " << WIRE << a.instance_prefix << "_" << outs.name << ";" << std::endl;
      }
    }
  }

  /// \brief writes a call to a subroutine
  void writeSubroutineCall(std::string prefix, std::ostream& out, const t_subroutine_nfo *s, siliceParser::ParamListContext* plist) const
  {
    std::vector<std::string> params;
    getParams(plist, params, nullptr);
    // check num parameters
    if (s->inputs.size() != params.size()) {
      throw Fatal("incorrect number of input parameters in call to subroutine '%s' (line %d)",
        s->name.c_str(), plist->getStart()->getLine());
    }
    // set inputs
    int p = 0;
    for (const auto& ins : s->inputs) {
      out << FF_D << prefix << s->vios.at(ins) << " = " << rewriteIdentifier(prefix, params[p++], nullptr) << ";" << std::endl;
    }
  }

  /// \brief writes reading back the results of a subroutine
  void writeSubroutineReadback(std::string prefix, std::ostream& out, const t_subroutine_nfo* s, siliceParser::ParamListContext* plist) const
  {
    std::vector<std::string> params;
    getParams(plist, params, nullptr);
    // if params are empty we simply wait, otherwise we set the outputs
    if (s->outputs.size() != params.size()) {
      throw Fatal("incorrect number of output parameters reading back result from subroutine '%s' (line %d)",
        s->name.c_str(), plist->getStart()->getLine());
    }
    // read outputs
    int p = 0;
    for (const auto& outs : s->outputs) {
      out << rewriteIdentifier(prefix, params[p++], nullptr) << " = " << FF_D << prefix << s->vios.at(outs) << std::endl;
    }
  }

  /// \brief determines identifier bit width and (if applicable) table size
  std::tuple<e_Type, int, int> determineIdentifierTypeWidthAndTableSize(antlr4::tree::TerminalNode *identifier,int line) const
  {
    sl_assert(identifier != nullptr);
    std::string vname = identifier->getText();
    // get width
    e_Type type    = Int;
    int width      = -1;
    int table_size = 0;
    // test if variable
    if (m_VarNames.find(vname) != m_VarNames.end()) {
      type       = m_Vars[m_VarNames.at(vname)].base_type;
      width      = m_Vars[m_VarNames.at(vname)].width;
      table_size = m_Vars[m_VarNames.at(vname)].table_size;
    } else if (m_InputNames.find(vname) != m_InputNames.end()) {
      type       = m_Inputs[m_InputNames.at(vname)].base_type;
      width      = m_Inputs[m_InputNames.at(vname)].width;
      table_size = m_Inputs[m_InputNames.at(vname)].table_size;
    } else if (m_OutputNames.find(vname) != m_OutputNames.end()) {
      type       = m_Outputs[m_OutputNames.at(vname)].base_type;
      width      = m_Outputs[m_OutputNames.at(vname)].width;
      table_size = m_Outputs[m_OutputNames.at(vname)].table_size;
    } else {
      throw Fatal("variable '%s' not yet declared (line %d)", vname.c_str(), line);
    }
    return std::make_tuple(type, width, table_size);
  }

  /// \brief determines identifier type and width
  std::pair<e_Type, int> determineIdentifierTypeAndWidth(antlr4::tree::TerminalNode *identifier, int line) const
  {
    sl_assert(identifier != nullptr);
    auto tws = determineIdentifierTypeWidthAndTableSize(identifier, line);
    return std::make_pair(std::get<0>(tws), std::get<1>(tws));
  }

  /// \brief determines IO access bit width
  std::pair<e_Type, int> determineIOAccessTypeAndWidth(siliceParser::IoAccessContext *ioaccess) const
  {
    sl_assert(ioaccess != nullptr);
    std::string algo = ioaccess->algo->getText();
    std::string io   = ioaccess->io->getText();
    // find algorithm
    auto A = m_InstancedAlgorithms.find(algo);
    if (A == m_InstancedAlgorithms.end()) {
      throw Fatal("cannot find algorithm instance '%s' (line %d)", algo.c_str(), ioaccess->getStart()->getLine());
    } else {
      if (!A->second.algo->isInput(io) && !A->second.algo->isOutput(io)) {
        throw Fatal("'%s' is neither an input not an output, instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
      }
      if (A->second.algo->isInput(io)) {
        if (A->second.boundinputs.count(io) > 0) {
          throw Fatal("cannot access bound input '%s' on instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
        }
        return std::make_pair(
          A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(io)].base_type,
          A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(io)].width
          );
      } else if (A->second.algo->isOutput(io)) {
        return std::make_pair(
          A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(io)].base_type,
          A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(io)].width
          );
      } else {
        sl_assert(false);
      }
    }
    sl_assert(false);
    return std::make_pair(Int,0);
  }

  /// \brief determines bit access type/width
  std::pair<e_Type, int> determineBitAccessTypeAndWidth(siliceParser::BitAccessContext *bitaccess) const
  {
    sl_assert(bitaccess != nullptr);
    if (bitaccess->IDENTIFIER() != nullptr) {
      return determineIdentifierTypeAndWidth(bitaccess->IDENTIFIER(), (int)bitaccess->getStart()->getLine());
    } else if (bitaccess->tableAccess() != nullptr) {
      return determineTableAccessTypeAndWidth(bitaccess->tableAccess());
    } else {
      return determineIOAccessTypeAndWidth(bitaccess->ioAccess());
    }
  }

  /// \brief determines table access type/width
  std::pair<e_Type, int> determineTableAccessTypeAndWidth(siliceParser::TableAccessContext *tblaccess) const
  {
    sl_assert(tblaccess != nullptr);
    if (tblaccess->IDENTIFIER() != nullptr) {
      return determineIdentifierTypeAndWidth(tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
    } else {
      return determineIOAccessTypeAndWidth(tblaccess->ioAccess());
    }
  }

  /// \brief determines access type/width
  std::pair<e_Type,int> determineAccessTypeAndWidth(siliceParser::AccessContext *access, antlr4::tree::TerminalNode *identifier) const
  {
    if (access) {
      // table, output or bits
      if (access->ioAccess() != nullptr) {
        return determineIOAccessTypeAndWidth(access->ioAccess());
      } else if (access->tableAccess() != nullptr) {
        return determineTableAccessTypeAndWidth(access->tableAccess());
      } else if (access->bitAccess() != nullptr) {
        return determineBitAccessTypeAndWidth(access->bitAccess());
      }
    } else {
      // identifier
      return determineIdentifierTypeAndWidth(identifier, (int)identifier->getSymbol()->getLine());
    }
    sl_assert(false);
    return std::make_pair(Int,0);
  }

  /// \brief writes access to an algorithm in/out
  t_inout_nfo writeIOAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::IoAccessContext* ioaccess) const
  {
    std::string algo = ioaccess->algo->getText();
    std::string io   = ioaccess->io->getText();
    // find algorithm
    auto A = m_InstancedAlgorithms.find(algo);
    if (A == m_InstancedAlgorithms.end()) {
      throw Fatal("cannot find algorithm instance '%s' (line %d)", algo.c_str(), ioaccess->getStart()->getLine());
    } else {
      if (!A->second.algo->isInput(io) && !A->second.algo->isOutput(io)) {
        throw Fatal("'%s' is neither an input not an output, instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
      }
      if (assigning && !A->second.algo->isInput(io)) {
        throw Fatal("cannot write to algorithm output '%s', instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
      }
      if (!assigning && !A->second.algo->isOutput(io)) {
        throw Fatal("cannot read from algorithm input '%s', instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
      }
      if (A->second.algo->isInput(io)) {
        if (A->second.boundinputs.count(io) > 0) {
          throw Fatal("cannot access bound input '%s' on instance '%s' (line %d)", io.c_str(), algo.c_str(), ioaccess->getStart()->getLine());
        }
        out << FF_D << A->second.instance_prefix << "_" << io;
        return A->second.algo->m_Inputs[A->second.algo->m_InputNames.at(io)];
      } else if (A->second.algo->isOutput(io)) {
        out << WIRE << A->second.instance_prefix << "_" << io;
        return A->second.algo->m_Outputs[A->second.algo->m_OutputNames.at(io)];
      } else {
        sl_assert(false);
      }
    }
    return t_inout_nfo();
  }

  /// \brief writes access to a table in/out
  void writeTableAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::TableAccessContext* tblaccess, int __id, const t_subroutine_nfo* sub) const
  {
    if (tblaccess->ioAccess() != nullptr) {
      t_inout_nfo nfo = writeIOAccess(prefix, out, assigning, tblaccess->ioAccess());
      out << "[(" << rewriteExpression(prefix, tblaccess->expression_0(), __id, sub) << ")*" << nfo.width << "+:" << nfo.width << ']';
    } else {
      sl_assert(tblaccess->IDENTIFIER() != nullptr);
      std::string vname = tblaccess->IDENTIFIER()->getText();
      out << rewriteIdentifier(prefix, vname, sub);
      // get width
      auto tws = determineIdentifierTypeWidthAndTableSize(tblaccess->IDENTIFIER(), (int)tblaccess->getStart()->getLine());
      // TODO: if the expression can be evaluated at compile time, we could check for access validity using table_size
      out << "[(" << rewriteExpression(prefix, tblaccess->expression_0(), __id, sub) << ")*" << std::get<1>(tws) << "+:" << std::get<1>(tws) << ']';
    }
  }

  /// \brief writes access to bits
  void writeBitAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitAccessContext* bitaccess, int __id, const t_subroutine_nfo* sub) const
  {
    // TODO: check access validity
    if (bitaccess->ioAccess() != nullptr) {
      writeIOAccess(prefix, out, assigning, bitaccess->ioAccess());
    } else if (bitaccess->tableAccess() != nullptr) {
      writeTableAccess(prefix, out, assigning, bitaccess->tableAccess(), __id, sub);
    } else {
      sl_assert(bitaccess->IDENTIFIER() != nullptr);
      out << rewriteIdentifier(prefix, bitaccess->IDENTIFIER()->getText(), sub);
    }
    out << '[' << rewriteExpression(prefix, bitaccess->first, __id, sub) << "+:" << bitaccess->num->getText() << ']';
  }

  /// \brief writes access to an identfier
  void writeAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::AccessContext* access, int __id, const t_subroutine_nfo* sub) const
  {
    if (access->ioAccess() != nullptr) {
      writeIOAccess(prefix, out, assigning, access->ioAccess());
    } else if (access->tableAccess() != nullptr) {
      writeTableAccess(prefix, out, assigning, access->tableAccess(), __id, sub);
    } else if (access->bitAccess() != nullptr) {
      writeBitAccess(prefix, out, assigning, access->bitAccess(), __id, sub);
    }
  }

  /// \brief writes an assignment
  void writeAssignement(std::string prefix, std::ostream& out,
    const t_instr_nfo& a, 
    siliceParser::AccessContext *access,
    antlr4::tree::TerminalNode* identifier,
    siliceParser::Expression_0Context *expression_0,
    const t_subroutine_nfo* sub) const
  {
    if (access) {
      // table, output or bits
      writeAccess(prefix, out, true, access, a.__id, sub);
    } else {
      sl_assert(identifier != nullptr);
      // variable
      if (isInput(identifier->getText())) {
        throw Fatal("cannot assign a value to an input of the algorithm, input '%s' (line %d)", 
          identifier->getText().c_str(), identifier->getSymbol()->getLine());
      }
      out << rewriteIdentifier(prefix, identifier->getText(), sub);
    }
    out << " = " + rewriteExpression(prefix, expression_0, a.__id, sub);
    out << ';' << std::endl;

  }

  /// \brief writes a single block to the output
  void writeBlock(std::string prefix, std::ostream& out, const t_combinational_block* block) const
  {
    // out << "// block " << block->block_name << std::endl;
    for (const auto& a : block->instructions) {
      {
        auto assign = dynamic_cast<siliceParser::AssignmentContext*>(a.instr);
        if (assign) {
          writeAssignement(prefix, out, a, assign->access(), assign->IDENTIFIER(), assign->expression_0(), block->subroutine);
        }
      } {
        auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(a.instr);
        if (alw) {
          if (alw->ALWSASSIGNDBL() != nullptr) {
            std::ostringstream ostr;
            writeAssignement(prefix, ostr, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), block->subroutine);
            // modify assignement to insert temporary var
            std::size_t pos    = ostr.str().find('=');
            std::string lvalue = ostr.str().substr(0, pos - 1);
            std::string rvalue = ostr.str().substr(pos + 1);
            std::string tmpvar = "_delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
            out << lvalue << " = " << FF_D << tmpvar << ';' << std::endl;
            out << FF_D << tmpvar << " = " << rvalue; // rvalue contains ";\n"
          } else {
            writeAssignement(prefix, out, a, alw->access(), alw->IDENTIFIER(), alw->expression_0(), block->subroutine);
          }
        }
      } {
        auto display = dynamic_cast<siliceParser::DisplayContext *>(a.instr);
        if (display) {
          out << "$display(" << display->STRING()->getText();
          if (display->displayParams() != nullptr) {
            for (auto p : display->displayParams()->IDENTIFIER()) {
              out << "," << rewriteIdentifier(prefix, p->getText(), block->subroutine, display->getStart()->getLine());
            }
          }
          out << ");" << std::endl;
        }
      } {
        auto async = dynamic_cast<siliceParser::AsyncExecContext*>(a.instr);
        if (async) {
          // find algorithm
          auto A = m_InstancedAlgorithms.find(async->IDENTIFIER()->getText());
          if (A == m_InstancedAlgorithms.end()) {
            // check if this is an erronous call to a subroutine
            auto S = m_Subroutines.find(async->IDENTIFIER()->getText());
            if (S == m_Subroutines.end()) {
              throw Fatal("cannot find algorithm '%s' on asynchronous call (line %d)",
                async->IDENTIFIER()->getText().c_str(), async->getStart()->getLine());
            } else {
              throw Fatal("cannot perform an asynchronous call on subroutine '%s' (line %d)",
                async->IDENTIFIER()->getText().c_str(), async->getStart()->getLine());
            }
          } else {
            writeAlgorithmCall(prefix, out, A->second, async->paramList(), block->subroutine);
          }
        }
      } {
        auto sync = dynamic_cast<siliceParser::SyncExecContext*>(a.instr);
        if (sync) {
          // find algorithm
          auto A = m_InstancedAlgorithms.find(sync->joinExec()->IDENTIFIER()->getText());
          if (A == m_InstancedAlgorithms.end()) {
            // call to a subroutine?
            auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
            if (S == m_Subroutines.end()) {
              throw Fatal("cannot find algorithm '%s' on synchronous call (line %d)",
                sync->joinExec()->IDENTIFIER()->getText().c_str(), sync->getStart()->getLine());
            } else {
              // check not already in subrountine
              if (block->subroutine != nullptr) {
                throw Fatal("cannot call a subrountine from another one (line %d)",sync->getStart()->getLine());
              }
              writeSubroutineCall(prefix, out, S->second, sync->paramList());
            }
          } else {
            writeAlgorithmCall(prefix, out, A->second, sync->paramList(), block->subroutine);
          }
        }
      } {
        auto join = dynamic_cast<siliceParser::JoinExecContext*>(a.instr);
        if (join) {
          // find algorithm
          auto A = m_InstancedAlgorithms.find(join->IDENTIFIER()->getText());
          if (A == m_InstancedAlgorithms.end()) {
            // return of subroutine?
            auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
            if (S == m_Subroutines.end()) {
              throw Fatal("cannot find algorithm '%s' to join with (line %d)",
                join->IDENTIFIER()->getText().c_str(), join->getStart()->getLine());
            } else {
              // check not already in subrountine
              if (block->subroutine != nullptr) {
                throw Fatal("cannot call a subrountine from another one (line %d)", join->getStart()->getLine());
              }
              writeSubroutineReadback(prefix, out, S->second, join->paramList());
            }

          } else {
            writeAlgorithmReadback(prefix, out, A->second, join->paramList(), block->subroutine);
          }
        }
      }
    }
  }

private:

    /// \brief determine variables/inputs/outputs access within an instruction (from its tree)
    void determineVIOAccess(
      antlr4::tree::ParseTree*                   node,
      const std::unordered_map<std::string,int>& vios,
      t_subroutine_nfo                          *sub,
      std::unordered_set<std::string>& _read, std::unordered_set<std::string>& _written)
    {
      if (node->children.empty()) {
        // read accesses are children
        auto term = dynamic_cast<antlr4::tree::TerminalNode*>(node);
        if (term) {
          if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
            std::string var = term->getText();
            if (sub) { // override name if in subroutine
              auto V = sub->vios.find(var);
              if (V != sub->vios.end()) {
                var = V->second;
              }
            }
            if (vios.find(var) != vios.end()) {
              _read.insert(var);
            }
          }
        }
      } else {
        // track writes explicitely
        bool recurse = true;
        {
          auto assign = dynamic_cast<siliceParser::AssignmentContext*>(node);
          if (assign) {
            std::string var;
            if (assign->access() != nullptr) {
              if (assign->access()->tableAccess() != nullptr) {
                var = assign->access()->tableAccess()->IDENTIFIER()->getText();
              } else if (assign->access()->bitAccess() != nullptr) {
                var = assign->access()->bitAccess()->IDENTIFIER()->getText();
              } else {
                // instanced algorithm input
              }
            } else {
              var = assign->IDENTIFIER()->getText();
            }
            if (sub) { // override name if in subroutine
              auto V = sub->vios.find(var);
              if (V != sub->vios.end()) {
                var = V->second;
              }
            }
            if (!var.empty() && vios.find(var) != vios.end()) {
              _written.insert(var);
            }
            determineVIOAccess(assign->expression_0(), vios, sub, _read,_written);
            recurse = false;
          }
        } {
          auto alw = dynamic_cast<siliceParser::AlwaysAssignedContext*>(node);
          if (alw) {
            std::string var;
            if (alw->access() != nullptr) {
              if (alw->access()->tableAccess() != nullptr) {
                var = alw->access()->tableAccess()->IDENTIFIER()->getText();
              } else if (alw->access()->bitAccess() != nullptr) {
                var = alw->access()->bitAccess()->IDENTIFIER()->getText();
              } else {
                // instanced algorithm input
              }
            } else {
              var = alw->IDENTIFIER()->getText();
            }
            if (sub) { // override name if in subroutine
              auto V = sub->vios.find(var);
              if (V != sub->vios.end()) {
                var = V->second;
              }
            }
            if (vios.find(var) != vios.end()) {
              _written.insert(var);
            }
            if (alw->ALWSASSIGNDBL() != nullptr) { // delayed flip-flop
              // update temp var usage
              std::string tmpvar = "delayed_" + std::to_string(alw->getStart()->getLine()) + "_" + std::to_string(alw->getStart()->getCharPositionInLine());
              _read   .insert(tmpvar);
              _written.insert(tmpvar);
            }
            determineVIOAccess(alw->expression_0(), vios, sub, _read, _written);
            recurse = false;
          }
        } {
          auto sync = dynamic_cast<siliceParser::SyncExecContext*>(node);
          if (sync) {
            // calling a subroutine?
            auto S = m_Subroutines.find(sync->joinExec()->IDENTIFIER()->getText());
            if (S != m_Subroutines.end()) {
              for (const auto& i : S->second->inputs) {
                _written.insert(S->second->vios.at(i));
              }
            }
            recurse = true; // detect reads
          }
        } {
          auto join = dynamic_cast<siliceParser::JoinExecContext*>(node);
          if (join) {
            // readback results from a subroutine?
            auto S = m_Subroutines.find(join->IDENTIFIER()->getText());
            if (S != m_Subroutines.end()) {
              for (const auto& o : S->second->outputs) {
                _read.insert(S->second->vios.at(o));
              }
            }
            recurse = true; // detect reads
          }
        }
        // recurse
        if (recurse) {
          for (auto c : node->children) {
            determineVIOAccess(c, vios, sub, _read, _written);
          }
        }
      }
    }

    /// \brief determines variable access within a block
    void determineVariablesAccess(t_combinational_block *block)
    {
      // determine variable access
      std::unordered_set<std::string> already_read;
      std::unordered_set<std::string> already_written;
      std::vector<t_instr_nfo> instr = block->instructions;
      if (block->if_then_else()) {
        instr.push_back(block->if_then_else()->test);
      }
      if (block->switch_case()) {
        instr.push_back(block->switch_case()->test);
      }
      if (block->while_loop()) {
        instr.push_back(block->while_loop()->test);
      }
      for (const auto& i : instr) {
        std::unordered_set<std::string> read;
        std::unordered_set<std::string> written;
        determineVIOAccess(i.instr, m_VarNames, block->subroutine, read, written);
        // record which are read from outside
        for (auto r : read) {
          // if read and not written before in block
          if (already_written.find(r) == already_written.end()) {
            block->in_vars_read.insert(r); // value from prior block is read
          }
        }
        // record which are written to
        already_written.insert(written.begin(), written.end());
        block->out_vars_written.insert(written.begin(), written.end());
        // update global variable use
        for (auto r : read) {
          m_Vars[m_VarNames[r]].access = (e_Access)(m_Vars[m_VarNames[r]].access | e_ReadOnly);
        }
        for (auto w : written) {
          m_Vars[m_VarNames[w]].access = (e_Access)(m_Vars[m_VarNames[w]].access | e_WriteOnly);
        }
      }
    }

    /// \brief determine variable access within algorithm
    void determineVariablesAccess()
    {
      // for all blocks
      // TODO: some blocks may never be reached ...
      for (auto& b : m_Blocks) {
        determineVariablesAccess(b);
      }
      // determine variable access for always block
      determineVariablesAccess(&m_Always);
      // determine variable access due to algorithm and module instances
      std::vector<t_binding_nfo> all_bindings;
      for (const auto& m : m_InstancedModules) {
        all_bindings.insert(all_bindings.end(), m.second.bindings.begin(), m.second.bindings.end());
      }
      for (const auto& a : m_InstancedAlgorithms) {
        all_bindings.insert(all_bindings.end(), a.second.bindings.begin(), a.second.bindings.end());
      }
      for (const auto& b : all_bindings) {
        // variables are always on the right
        if (m_VarNames.find(b.right) != m_VarNames.end()) {
          if (b.dir == e_Left) {
            // add to always block dependency
            m_Always.in_vars_read.insert(b.right);
            // set global access
            m_Vars[m_VarNames[b.right]].access = (e_Access)(m_Vars[m_VarNames[b.right]].access | e_ReadOnly);
          } else if (b.dir == e_Right) {
            // add to always block dependency
            m_Always.out_vars_written.insert(b.right);
            // set global access
            // -> check prior access
            if (m_Vars[m_VarNames[b.right]].access & e_WriteOnly) {
              throw Fatal("cannot write to variable '%s' bound to an algorithm or module output (line %d)", b.right.c_str(),b.line);
            }
            // -> mark as write-binded
            m_Vars[m_VarNames[b.right]].access = (e_Access)(m_Vars[m_VarNames[b.right]].access | e_WriteBinded);
          } else {
            throw Fatal("cannot access inout variable '%s' (line %d) [inouts are only supported as pass-through to/from Verilog modules]", b.right.c_str(), b.line);
          }
        }
      }
      // determine variable access due to algorithm instances clocks and reset
      for (const auto& m : m_InstancedAlgorithms) {
        std::vector<std::string> candidates;
        candidates.push_back(m.second.instance_clock);
        candidates.push_back(m.second.instance_reset);
        for (auto v : candidates) {
          // variables are always on the right
          if (m_VarNames.find(v) != m_VarNames.end()) {
            // add to always block dependency
            m_Always.in_vars_read.insert(v);
            // set global access
            m_Vars[m_VarNames[v]].access = (e_Access)(m_Vars[m_VarNames[v]].access | e_ReadOnly);
          }
        }
      }
    }

    /// \brief analyze variables access and classifies variables
    void analyzeVariablesAccess()
    {
      // determine variables access
      determineVariablesAccess();
      // analyze usage
      auto blocks = m_Blocks;
      blocks.push_front(&m_Always);
      // merge all in_reads and out_written
      std::unordered_set<std::string> global_in_read;
      std::unordered_set<std::string> global_out_written;
      for (const auto& b : blocks) {
        global_in_read    .insert(b->in_vars_read.begin(),     b->in_vars_read.end());
        global_out_written.insert(b->out_vars_written.begin(), b->out_vars_written.end());
      }
      std::cerr << "---< variables >---" << std::endl;
      for (auto& v : m_Vars) {
        if (v.access == e_ReadOnly) {
          std::cerr << v.name << " => const ";
          v.usage = e_Const;
        } else if (v.access == e_WriteOnly) {
          std::cerr << v.name << " => written but not used ";
          v.usage = e_Temporary; // e_NotUsed;
        } else if (v.access == e_ReadWrite) {
          if (global_in_read.find(v.name) == global_in_read.end()) {
            std::cerr << v.name << " => temp ";
            v.usage = e_Temporary;
          } else {
            std::cerr << v.name << " => flip-flop ";
            v.usage = e_FlipFlop;
          }
        } else if (v.access == (e_WriteBinded | e_ReadOnly)) {
          std::cerr << v.name << " => write-binded ";
          v.usage = e_Bound;
        } else if (v.access == (e_WriteBinded)) {
          std::cerr << v.name << " => write-binded but not used ";
          v.usage = e_Bound;
        } else if (v.access == e_NotAccessed) {
          std::cerr << v.name << " => unused ";
          v.usage = e_NotUsed;
        } else {
          std::cerr << Console::yellow << "warning: " << v.name << " unexpected usage." << Console::gray << std::endl;
        }
        std::cerr << std::endl;
      }

#if 0
      /////////// DEBUG
      for (const auto& v : m_Vars) {
        cerr << v.name << " access: ";
        if (v.access & e_ReadOnly) cerr << 'R';
        if (v.access & e_WriteOnly) cerr << 'W';
        std::cerr << std::endl;
      }
      for (const auto& b : blocks) {
        std::cerr << "== block " << b->block_name << "==" << std::endl;
        std::cerr << "   read from before: ";
        for (auto i : b->in_vars_read) {
          std::cerr << i << ' ';
        }
        std::cerr << std::endl;
        std::cerr << "   changed within: ";
        for (auto i : b->out_vars_written) {
          std::cerr << i << ' ';
        }
        std::cerr << std::endl;
      }
      /////////////////
#endif

    }

    /// \brief determines the list of bound VIO

    void determineModAlgBoundVIO()
    {
      // find out vio bound to a module input/output
      m_VIOBoundToModAlgOutputs.clear();
      for (const auto& im : m_InstancedModules) {
        for (const auto& bi : im.second.bindings) {
          if (bi.dir == e_Right) {
            // record wire name for this output
            m_VIOBoundToModAlgOutputs[bi.right] = WIRE + im.second.instance_prefix + "_" + bi.left;
          }
        }
      }
      // find out vio bound to an algorithm output
      for (const auto& ia : m_InstancedAlgorithms) {
        for (const auto& bi : ia.second.bindings) {
          if (bi.dir == e_Right) {
            // record wire name for this output
            m_VIOBoundToModAlgOutputs[bi.right] = WIRE + ia.second.instance_prefix + "_" + bi.left;
          }
        }
      }
    }

    /// \brief analyze usage of inputs of instanced algorithms
    void analyzeInstancedAlgorithmsInputs()
    {
      for (auto& ia : m_InstancedAlgorithms) {
        for (const auto& b : ia.second.bindings) {
          if (b.dir == e_Left) { // setting input
            // input is bound directly
            ia.second.boundinputs.insert(std::make_pair(b.left,b.right));
          }
        }
      }
    }

    /// \brief analyze output accesses and classifies them
    void analyzeOutputsAccess()
    {
      // go through all instructions and determine access
      std::unordered_set<std::string> global_read;
      std::unordered_set<std::string> global_written;
      for (const auto& b : m_Blocks) {
        for (const auto& i : b->instructions) {
          std::unordered_set<std::string> read;
          std::unordered_set<std::string> written;
          determineVIOAccess(i.instr, m_OutputNames, b->subroutine, read, written);
          global_read   .insert(read.begin(),    read.end());
          global_written.insert(written.begin(), written.end());
        }
      }
      // always block
      std::unordered_set<std::string> always_read;
      std::unordered_set<std::string> always_written;
      for (const auto& i : m_Always.instructions) {
        std::unordered_set<std::string> read;
        std::unordered_set<std::string> written;
        determineVIOAccess(i.instr, m_OutputNames, nullptr, read, written);
        always_read   .insert(read.begin(), read.end());
        always_written.insert(written.begin(), written.end());
      }
      // analyze access and usage
      std::cerr << "---< outputs >---" << std::endl;
      for (auto& o : m_Outputs) {
        auto W = m_VIOBoundToModAlgOutputs.find(o.name);
        if (W != m_VIOBoundToModAlgOutputs.end()) {
          // bound to a wire
          if (global_written.find(o.name) != global_written.end()) {
            // NOTE: always caught before? (see determineVariablesAccess)
            throw Fatal((std::string("cannot write to an output bound to a module/algorithm (") + o.name + ")").c_str());
          }
          if (always_written.find(o.name) != always_written.end()) {
            // NOTE: always caught before? (see determineVariablesAccess)
            throw Fatal((std::string("cannot write to an output bound to a module/algorithm (") + o.name + ")").c_str());
          }
          o.usage = e_Bound;
          std::cerr << o.name << " => wire" << std::endl;
        } else if (
             global_written.find(o.name) == global_written.end()
          && global_read.find(o.name)    == global_read.end()
          && ( always_written.find(o.name) != always_written.end()
            || always_read.find(o.name)    != always_read.end()
            )
          ) {
          // not used in blocks but used in always block
          // only assigned (either way)
          // o.usage = e_Assigned; /////// TODO
          o.usage = e_FlipFlop;
          std::cerr << o.name << " => assigned" << std::endl;
        } else {
          // any other case: flip-flop
          // NOTE: outputs are always considered used externally (read)
          //       they also have to be set at each step of the algorithm (avoiding latches)
          //       thus as soon as used in a block != always, they become flip-flops
          o.usage = e_FlipFlop;
          std::cerr << o.name << " => flip-flop" << std::endl;
        }
      }
    }

    /// \brief Verifies validity of bindings on instanced modules
    void checkModulesBindings() const;

    /// \brief Verifies validity of bindings on instanced algorithms
    void checkAlgorithmsBindings() const;

public:

  /// \brief constructor
  Algorithm(std::string name, std::string clock, std::string reset, bool autorun, const std::unordered_map<std::string, AutoPtr<Module> >& known_modules)
    : m_Name(name), m_Clock(clock), m_Reset(reset), m_AutoRun(autorun), m_KnownModules(known_modules)
  {
    // init with empty always block
    m_Always.id = 0;
    m_Always.block_name = "_always";
  }

  /// \brief sets the input parsed tree
  void gather(siliceParser::InOutListContext *inout, antlr4::tree::ParseTree *declAndInstr)
  {
    // gather elements from source code
    t_combinational_block *main = addBlock("_top",(int)inout->getStart()->getLine());
    main->is_state = true;

    // gather input and outputs
    gatherIOs(inout);

    // semantic pass
    t_gather_context context;
    context.__id     = -1;
    context.break_to = nullptr;
    gather(declAndInstr, main, &context);

    // resolve forward refs
    resolveForwardJumpRefs();

    // generate states
    generateStates();
  }

  /// \brief autobind algorithm
  void autobindInstancedAlgorithm(t_algo_nfo& _alg);

  /// \brief resolve instanced algorithms refs
  void resolveAlgorithmRefs(const std::unordered_map<std::string, AutoPtr<Algorithm> >& algorithms)
  {
    for (auto& nfo : m_InstancedAlgorithms) {
      const auto& A = algorithms.find(nfo.second.algo_name);
      if (A == algorithms.end()) {
        throw Fatal("algorithm '%s' not found, instance '%s' (line %d)", 
          nfo.second.algo_name.c_str(),
          nfo.second.instance_name.c_str(),
          nfo.second.instance_line);
      }
      nfo.second.algo = A->second;
      // check autobind
      if (nfo.second.autobind) {
        autobindInstancedAlgorithm(nfo.second);
      }
    }
  }

  /// \brief autobind module
  void autobindInstancedModule(t_module_nfo& _mod);

  /// \brief resolve instanced modules refs
  void resolveModuleRefs(const std::unordered_map<std::string, AutoPtr<Module> >& modules)
  {
    for (auto& nfo : m_InstancedModules) {
      const auto& M = modules.find(nfo.second.module_name);
      if (M == modules.end()) {
        throw Fatal("module '%s' not found, instance '%s' (line %d)",
          nfo.second.module_name.c_str(),
          nfo.second.instance_name.c_str(),
          nfo.second.instance_line);
      }
      nfo.second.mod = M->second;
      // check autobind
      if (nfo.second.autobind) {
        autobindInstancedModule(nfo.second);
      }
    }
  }
   
  /// \brief Run optimizations
  void optimize()
  {
    // check bindings
    checkModulesBindings();
    checkAlgorithmsBindings();
    // determine which VIO are assigned to wires
    determineModAlgBoundVIO();
    // analyze variables access 
    analyzeVariablesAccess();
    // analyze outputs access
    analyzeOutputsAccess();
    // analyze instanced algorithms inputs
    analyzeInstancedAlgorithmsInputs();
  }

private:

  /// \brief writes flip-flop value init for a variable
  void writeVarFlipFlopInit(std::string prefix, std::ostream& out, const t_var_nfo& v) const
  {
    out << FF_Q << prefix << v.name << " <= " << v.init_values[0] << ';' << std::endl;
  }

  /// \brief writes flip-flop value update for a variable
  void writeVarFlipFlopUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
  {
    out << FF_Q << prefix << v.name << " <= " << FF_D << prefix << v.name << ';' << std::endl;
  }

  /// \brief computes variable bit depdth
  int varBitDepth(const t_var_nfo& v) const
  {
    if (v.table_size == 0) {
      return v.width;
    } else {
      return v.width * v.table_size;
    }
  }

private:

  /// \brief writes the const declarations
  void writeConstDeclarations(std::string prefix, std::ostream& out) const
  {
    for (const auto& v : m_Vars) {
      if (v.usage != e_Const) continue;
      out << "wire " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << FF_D << prefix << v.name << ';' << std::endl;
      if (v.table_size == 0) {
        out << "assign " << FF_D << prefix << v.name << " = " << v.init_values[0] << ';' << std::endl;
      } else {
        int width = v.width;
        ForIndex(i, v.table_size) {
          out << "assign " << FF_D << prefix << v.name << '[' << (i*width) << "+:" << width << ']' << " = " << v.init_values[i] << ';' << std::endl;
        }
      }
    }
  }

  /// \brief returns a type dependent string for resource declaration
  std::string typeString(const t_var_nfo& v) const 
  {
    if (v.base_type == Int) {
      return "signed";
    }
    return "";
  }

  /// \brief writes the temporary declarations
  void writeTempDeclarations(std::string prefix, std::ostream& out) const
  {
    for (const auto& v : m_Vars) {
      if (v.usage != e_Temporary) continue;
      out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] " << FF_D << prefix << v.name << ';' << std::endl;
    }
  }

  /// \brief writes the flip-flop declarations
  void writeFlipFlopDeclarations(std::string prefix, std::ostream& out) const
  {
    out << std::endl;
    // flip-flops for internal vars
    for (const auto& v : m_Vars) {
      if (v.usage != e_FlipFlop) continue;
      out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] ";
      out << FF_D << prefix << v.name << ',' << FF_Q << prefix << v.name << ';' << std::endl;
    }
    // flip-flops for outputs
    for (const auto& v : m_Outputs) {
      if (v.usage == e_FlipFlop) {
        out << "reg " << typeString(v) << " [" << varBitDepth(v) - 1 << ":0] ";
        out << FF_D << prefix << v.name << ',' << FF_Q << prefix << v.name << ';' << std::endl;
      }
    }
    // flip-flops for algorithm inputs that are not bound
    for (const auto &ia : m_InstancedAlgorithms) {
      for (const auto &is : ia.second.algo->m_Inputs) {
        if (ia.second.boundinputs.count(is.name) == 0) {
          out << "reg " << typeString(is) << " [" << varBitDepth(is) - 1 << ":0] ";
          out << FF_D << ia.second.instance_prefix << '_' << is.name << ',' << FF_Q << ia.second.instance_prefix << '_' << is.name << ';' << std::endl;
        }
      }
    }
    // state machine index
    out << "reg [" << stateWidth() << ":0] " FF_D << prefix << ALG_IDX "," FF_Q << prefix << ALG_IDX << ';' << std::endl;
    // state machine return (subroutine)
    out << "reg[" << stateWidth() << ":0] " FF_D << prefix << ALG_RETURN "," FF_Q << prefix << ALG_RETURN << ';' << std::endl;
    // state machine run for instanced algorithms
    for (const auto& ia : m_InstancedAlgorithms) {
      out << "reg " << ia.second.instance_prefix + "_" ALG_RUN << ';' << std::endl;
    }
  }

  /// \brief writes the flip-flops
  void writeFlipFlops(std::string prefix, std::ostream& out) const
  {
    // output flip-flop init and update on clock
    out << std::endl;
    std::string clock = m_Clock;
    if (m_Clock != ALG_CLOCK) {
      // in this case, clock has to be bound to a module output
      auto C = m_VIOBoundToModAlgOutputs.find(m_Clock);
      if (C == m_VIOBoundToModAlgOutputs.end()) {
        throw std::runtime_error("clock is not bound to any module output");
      }
      clock = C->second;
    }
    
    out << "always @(posedge " << clock << ") begin" << std::endl;
    
    /// init on hardware reset
    std::string reset = m_Reset;
    if (m_Reset != ALG_RESET) {
      // in this case, clock has to be bound to a module output
      auto R = m_VIOBoundToModAlgOutputs.find(m_Reset);
      if (R == m_VIOBoundToModAlgOutputs.end()) {
        throw std::runtime_error("reset is not bound to any module output");
      }
      reset = R->second;
    }
    out << "  if (" << reset << " || !in_run) begin" << std::endl;
    for (const auto& v : m_Vars) {
      if (v.usage != e_FlipFlop) continue;
      writeVarFlipFlopInit(prefix, out, v);
    }
    for (const auto& v : m_Outputs) {
      if (v.usage == e_FlipFlop) {
        writeVarFlipFlopInit(prefix, out, v);
      }
    }
    for (const auto &ia : m_InstancedAlgorithms) {
      for (const auto &is : ia.second.algo->m_Inputs) {
        if (ia.second.boundinputs.count(is.name) == 0) {
          writeVarFlipFlopInit(ia.second.instance_prefix + '_', out, is);
        }
      }
    }
    // state machine 
    // -> on reset
    out << "  if (" << reset << ") begin" << std::endl;
    if (!m_AutoRun) {
      // no autorun: jump to halt state
      out << FF_Q << prefix << ALG_IDX   " <= " << terminationState() << ";" << std::endl;
    } else {
      // autorun: jump to first state
      out << FF_Q << prefix << ALG_IDX   " <= " << fastForward(m_Blocks.front())->state_id << ";" << std::endl;
    }
    out << "end else begin" << std::endl;
    // -> on restart, jump to first state
    out << FF_Q << prefix << ALG_IDX   " <= " << fastForward(m_Blocks.front())->state_id << ";" << std::endl;
    out << "end" << std::endl;
    // return index for subroutines
    out << FF_Q << prefix << ALG_RETURN " <= " << terminationState() << ";" << std::endl;
    
    /// updates on clockpos
    out << "  end else begin" << std::endl;
    for (const auto& v : m_Vars) {
      if (v.usage != e_FlipFlop) continue;
      writeVarFlipFlopUpdate(prefix, out, v);
    }
    for (const auto& v : m_Outputs) {
      if (v.usage == e_FlipFlop) {
        writeVarFlipFlopUpdate(prefix, out, v);
      }
    }
    for (const auto &ia : m_InstancedAlgorithms) {
      for (const auto &is : ia.second.algo->m_Inputs) {
        if (ia.second.boundinputs.count(is.name) == 0) {
          writeVarFlipFlopUpdate(ia.second.instance_prefix + '_', out, is);
        }
      }
    }
    // state machine index
    out << FF_Q << prefix << ALG_IDX " <= " FF_D << prefix << ALG_IDX << ';' << std::endl;
    // state machine return
    out << FF_Q << prefix << ALG_RETURN " <= " FF_D << prefix << ALG_RETURN << ';' << std::endl;
    out << "  end" << std::endl;
    out << "end" << std::endl;
  }

private:

  /// \brief writes flip-flop combinational value update for a variable
  void writeVarFlipFlopCombinationalUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const
  {
    out << FF_D << prefix << v.name << " = " << FF_Q << prefix << v.name << ';' << std::endl;
  }

  void writeCombinationalAlways(std::string prefix, std::ostream& out) const
  {
    // flip-flops
    for (const auto& v : m_Vars) {
      if (v.usage != e_FlipFlop) continue;
      writeVarFlipFlopCombinationalUpdate(prefix, out, v);
    }
    for (const auto& v : m_Outputs) {
      if (v.usage == e_FlipFlop) {
        writeVarFlipFlopCombinationalUpdate(prefix, out, v);
      }
    }
    for (const auto &ia : m_InstancedAlgorithms) {
      for (const auto &is : ia.second.algo->m_Inputs) {
        if (ia.second.boundinputs.count(is.name) == 0) {
          writeVarFlipFlopCombinationalUpdate(ia.second.instance_prefix + '_', out, is);
        }
      }
    }
    // state machine index
    out << FF_D << prefix << ALG_IDX " = " FF_Q << prefix << ALG_IDX << ';' << std::endl;
    // state machine index
    out << FF_D << prefix << ALG_RETURN " = " FF_Q << prefix << ALG_RETURN << ';' << std::endl;
    // instanced algorithms run, maintain high
    for (auto ia : m_InstancedAlgorithms) {
      out << ia.second.instance_prefix + "_" ALG_RUN " = 1;" << std::endl;
    }
    // instanced modules input/output bindings with wires
    // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
    for (auto im : m_InstancedModules) {
      for (auto b : im.second.bindings) {
        if (b.dir == e_Right) { // output
          if (m_VarNames.find(b.right) != m_VarNames.end()) {
            // bound to variable, the variable is replaced by the output wire
            auto usage = m_Vars.at(m_VarNames.at(b.right)).usage;
            sl_assert(usage == e_Bound);
          } else if (m_OutputNames.find(b.right) != m_OutputNames.end()) {
            // bound to an algorithm output
            auto usage = m_Outputs.at(m_OutputNames.at(b.right)).usage;
            if (usage == e_FlipFlop) {
              out << FF_D << prefix + b.right + " = " + WIRE + im.second.instance_prefix + "_" + b.left << ';' << std::endl;
            }
          }
        }
      }
    }
    // instanced algorithms input/output bindings with wires
    // NOTE: could this be done with assignements (see Algorithm::writeAsModule) ?
    for (auto ia : m_InstancedAlgorithms) {
      for (auto b : ia.second.bindings) {
        if (b.dir == e_Right) { // output
          if (m_VarNames.find(b.right) != m_VarNames.end()) {
            // bound to variable, the variable is replaced by the output wire
            auto usage = m_Vars.at(m_VarNames.at(b.right)).usage;
            sl_assert(usage == e_Bound);
          } else if (m_OutputNames.find(b.right) != m_OutputNames.end()) {
            // bound to an algorithm output
            auto usage = m_Outputs.at(m_OutputNames.at(b.right)).usage;
            if (usage == e_FlipFlop) {
              // the output is a flip-flop, copy from the wire
              out << FF_D << prefix + b.right + " = " + WIRE + ia.second.instance_prefix + "_" + b.left << ';' << std::endl;
            }
            // else, the output is replaced by the wire
          }
        } 
      }
    }
    // always block (if not empty)
    if (!m_Always.instructions.empty()) {
      writeBlock(prefix, out, &m_Always);
    }
  }

  /// \brief add a state to the queue
  void pushState(const t_combinational_block* b, std::queue<size_t>& _q) const
  {
    if (b->is_state) {
      size_t rn = fastForward(b)->id;
      _q.push(rn);
    }
  }

  /// \brief writes a graph of stateless blocks to the output, until a jump to other states is reached
  void writeStatelessBlockGraph(std::string prefix, std::ostream& out,const t_combinational_block* block, const t_combinational_block* stop_at, std::queue<size_t>& _q) const
  {
    // recursive call?
    if (stop_at != nullptr) {
      // if called is a state, index state and stop there
      if (block->is_state) {
        // yes: index the state directly
        out << FF_D << prefix << ALG_IDX " = " << fastForward(block)->state_id << ";" << std::endl;
        pushState(block, _q);
        // return
        return;
      }
    }
    // follow the chain
    const t_combinational_block *current = block;
    while (true) {
      // write current block
      writeBlock(prefix, out, current);
      // goto next in chain
      if (current->next()) {
        current = current->next()->next;
      } else if (current->if_then_else()) {
        out << "if (" << rewriteExpression(prefix, current->if_then_else()->test.instr, current->if_then_else()->test.__id, current->subroutine) << ") begin" << std::endl;
        // recurse if
        writeStatelessBlockGraph(prefix, out, current->if_then_else()->if_next, current->if_then_else()->after, _q);
        out << "end else begin" << std::endl;
        // recurse else
        writeStatelessBlockGraph(prefix, out, current->if_then_else()->else_next, current->if_then_else()->after, _q);
        out << "end" << std::endl;
        // follow after?
        if (current->if_then_else()->after->is_state) {
          return; // no: already indexed by recursive calls
        } else {
          current = current->if_then_else()->after; // yes!
        }
      } else if (current->switch_case()) {
        out << "  case (" << rewriteExpression(prefix, current->switch_case()->test.instr, current->switch_case()->test.__id, current->subroutine) << ")" << std::endl;
        // recurse block
        for (auto cb : current->switch_case()->case_blocks) {
          out << "  " << cb.first << ": begin" << std::endl;
          writeStatelessBlockGraph(prefix, out, cb.second, current->switch_case()->after, _q);
          out << "  end" << std::endl;
        }
        // end of case
        out << "endcase" << std::endl;
        // follow after?
        if (current->switch_case()->after->is_state) {
          return; // no: already indexed by recursive calls
        } else {
          current = current->switch_case()->after; // yes!
        }
      } else if (current->while_loop()) {
        // while
        out << "if (" << rewriteExpression(prefix, current->while_loop()->test.instr, current->while_loop()->test.__id, current->subroutine) << ") begin" << std::endl;
        writeStatelessBlockGraph(prefix, out, current->while_loop()->iteration, current->while_loop()->after, _q);
        out << "end else begin" << std::endl;
        out << FF_D << prefix << ALG_IDX " = " << fastForward(current->while_loop()->after)->state_id << ";" << std::endl;
        pushState(current->while_loop()->after, _q);
        out << "end" << std::endl;
        return;
      } else if (current->return_from()) {
        // return to caller (goes to termination of algorithm is not set)
        out << FF_D << prefix << ALG_IDX " = " << FF_D << prefix << ALG_RETURN << ";" << std::endl;
        // reset return index
        out << FF_D << prefix << ALG_RETURN " = " << terminationState() << ";" << std::endl;
        return;
      } else if (current->goto_and_return_to()) {
        // goto subroutine
        out << FF_D << prefix << ALG_IDX " = " << fastForward(current->goto_and_return_to()->go_to)->state_id << ";" << std::endl;
        pushState(current->goto_and_return_to()->go_to, _q);
        // set return index
        out << FF_D << prefix << ALG_RETURN " = " << fastForward(current->goto_and_return_to()->return_to)->state_id << ";" << std::endl;
        pushState(current->goto_and_return_to()->return_to, _q);
        return;
      } else if (current->wait()) {
        // wait for algorithm
        auto A = m_InstancedAlgorithms.find(current->wait()->algo_instance_name);
        if (A == m_InstancedAlgorithms.end()) {
          throw Fatal("cannot find algorithm '%s' to join with (line %d)",
            current->wait()->algo_instance_name.c_str(), 
            current->wait()->line);
        } else {
          // test if algorithm is done
          out << "if (" WIRE << A->second.instance_prefix + "_" + ALG_DONE " == 1) begin" << std::endl;
          // yes!
          // -> goto next
          out << FF_D << prefix << ALG_IDX " = " << fastForward(current->wait()->next)->state_id << ";" << std::endl;
          pushState(current->wait()->next, _q);
          out << "end else begin" << std::endl;
          // no!
          // -> wait
          out << FF_D << prefix << ALG_IDX " = " << fastForward(current->wait()->waiting)->state_id << ";" << std::endl;
          pushState(current->wait()->waiting, _q);
          out << "end" << std::endl;
        }
        return;
      } else {
        // no action: jump to terminal state
        out << FF_D << prefix << ALG_IDX " = " << terminationState() << ";" << std::endl;
        return;
      }
      // check whether next is a state
      if (current->is_state) {
        // yes: index and stop
        out << FF_D << prefix << ALG_IDX " = " << fastForward(current)->state_id << ";" << std::endl;
        pushState(current, _q);
        return;
      }
      // reached stop?
      if (current == stop_at) {
        return;
      }
      // keep going
    }
  }

  /// \brief writes all states in the output
  void writeCombinationalStates(std::string prefix, std::ostream& out) const
  {
    std::unordered_set<size_t> produced;
    std::queue<size_t>         q;
    q.push(0); // starts at 0
    // states
    out << "case (" << FF_D << prefix << ALG_IDX << ")" << std::endl;
    while (!q.empty()) {
      size_t bid = q.front();
      const t_combinational_block *b = m_Id2Block.at(bid);
      sl_assert(b->state_id > -1);
      q.pop();
      // done already?
      if (produced.find(bid) == produced.end()) {
        produced.insert(bid);
      } else {
        // yes: skip
        continue;
      }
      // begin state
      out << b->state_id << ": begin" << " // " << b->block_name << std::endl;
      if (bid == 0) { // first block starts by variable initialization
        for (const auto& v : m_Vars) {
          if (v.usage != e_FlipFlop) continue;
          if (v.table_size == 0) {
            out << FF_D << prefix << v.name << " = " << v.init_values[0] << ';' << std::endl;
          } else {
            ForIndex(i, v.table_size) {
              out << FF_D << prefix << v.name << "[(" << i << ")*" << v.width << "+:" << v.width << ']' << " = " << v.init_values[i] << ';' << std::endl;
            }
          }
        }
      }
      // write block instructions
      writeStatelessBlockGraph(prefix, out, b, nullptr, q);
      // end of state
      out << "end" << std::endl;
    }
    // initiate termination sequence
    // -> termination state
    {
      out << terminationState() << ": begin // end of " << m_Name << std::endl;
      out << "end" << std::endl;
    }
    // default: internal error, should never happen
    {
      out << "default: begin " << std::endl;
      out << FF_D << prefix << ALG_IDX " = " << terminationState() << ";" << std::endl;
      out << " end" << std::endl;
    }
    out << "endcase" << std::endl;
  }

public:

  void writeAsModule(std::ostream& out) const;
};

// -------------------------------------------------
