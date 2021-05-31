/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007

With the additional clause that the copyright notice
above, identitfying the author and original copyright
holder must remain included in all distributions.

(header_1_0)
*/
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

/*
See GitHub Issues section for open/known issues.
*/

#include "siliceLexer.h"
#include "siliceParser.h"

#include "TypesAndConsts.h"

#include <string>
#include <iostream>
#include <fstream>
#include <regex>
#include <queue>
#include <unordered_set>
#include <unordered_map>
#include <numeric>
#include <variant>

#include <LibSL/LibSL.h>

class LuaPreProcessor;

// -------------------------------------------------

#define FF_D      "_d"
#define FF_Q      "_q"
#define FF_TMP    "_t"
#define FF_CST    "_c"
#define REG_      "_r"
#define WIRE      "_w"

#define ALG_INPUT   "in"
#define ALG_OUTPUT  "out"
#define ALG_INOUT   "inout"
#define ALG_IDX     "index"
#define ALG_RUN     "run"
#define ALG_AUTORUN "autorun"
#define ALG_CALLER  "caller"
#define ALG_DONE    "done"
#define ALG_CLOCK   "clock"
#define ALG_RESET   "reset"

// -------------------------------------------------

namespace Silice
{

  // -------------------------------------------------

  class Module;

  // -------------------------------------------------

  /// \brief class to parse, store and compile an algorithm definition
  class Algorithm
  {
  public:

    class LanguageError
    {
    public:
      enum { e_MessageBufferSize = 4096 };
    private:
      int            m_Line = -1;
      antlr4::Token          *m_Token = nullptr;
      antlr4::misc::Interval  m_Interval;
      char           m_Message[e_MessageBufferSize];
      LanguageError() { m_Message[0] = '\0'; }
    public:
      LanguageError(int line, antlr4::Token *tk, antlr4::misc::Interval interval, const char *msg, ...)
#if !defined(_WIN32) && !defined(_WIN64)
        __attribute__((format(printf, 5, 6)))
#endif
      {
        m_Line = line;
        m_Token = tk;
        m_Interval = interval;
        va_list args;
        va_start(args, msg);
        vsprintf_s(m_Message, e_MessageBufferSize, msg, args);
        va_end(args);
      }
      int line() const { return m_Line; }
      const char             *message()  const { return (m_Message); }
      antlr4::Token          *token() { return m_Token; }
      antlr4::misc::Interval  interval() { return m_Interval; }
    };


  private:

    /// \brief memory types
    enum e_MemType { BRAM, SIMPLEDUALBRAM, DUALBRAM, BROM };

    /// \brief algorithm name
    std::string m_Name;

    /// \brief algorithm clock
    std::string m_Clock = ALG_CLOCK;

    /// \brief algorithm reset
    std::string m_Reset = ALG_RESET;

    /// \brief whether algorithm autorun at startup
    bool m_AutoRun = false;

    /// \brief whether algorithm uses onehot state encoding
    bool m_OneHot = false;

    /// \brief Set of known modules
    const std::unordered_map<std::string, AutoPtr<Module> >& m_KnownModules;
    /// \brief Set of known subroutines
    const std::unordered_map<std::string, siliceParser::SubroutineContext*>& m_KnownSubroutines;
    /// \brief Set of known circuitries
    const std::unordered_map<std::string, siliceParser::CircuitryContext*>& m_KnownCircuitries;
    /// \brief Set of known groups
    const std::unordered_map<std::string, siliceParser::GroupContext*>& m_KnownGroups;
    /// \brief Set of known interfaces
    const std::unordered_map<std::string, siliceParser::IntrfaceContext*> &m_KnownInterfaces;
    /// \brief Set of known bitfields
    const std::unordered_map<std::string, siliceParser::BitfieldContext*>& m_KnownBitFields;

public:

    /// \brief enum for variable access
    /// e_ReadWrite = e_ReadOnly | e_WriteOnly
    enum e_Access {
      e_NotAccessed = 0,
      e_ReadOnly = 1,
      e_WriteOnly = 2,
      e_ReadWrite = 3,
      e_WriteBinded = 4,
      e_ReadWriteBinded = 8,
      e_InternalFlipFlop = 16
    };

    /// \brief enum for variable type
    enum e_VarUsage {
      e_Undetermined = 0,
      e_NotUsed = 1,
      e_Const = 2,
      e_Temporary = 3,
      e_FlipFlop = 4,
      e_Bound = 5,
      e_Wire = 6
    };

    /// \brief enum for variable type
    enum e_FFUsage {
      e_None = 0, e_D = 1, e_Q = 2, e_DQ = 3,
      e_Latch = 4, e_LatchD = 5, e_LatchQ = 6, e_LatchDQ = 7,
      e_NoLatch = 8
    };

    /// \brief enum for IO types
    enum e_IOType { e_Input, e_Output, e_InOut, e_NotIO };

    /// \brief base info about variables, inputs, outputs
    class t_var_nfo {
    public:
      std::string  name;
      t_type_nfo   type_nfo;
      std::vector<std::string> init_values;
      int          table_size; // 0: not a table, otherwise size
      bool         do_not_initialize = false;
      bool         init_at_startup   = false;
      std::string  pipeline_prev_name; // if not empty, name of previous in pipeline trickling
      e_Access     access = e_NotAccessed;
      e_VarUsage   usage = e_Undetermined;
      std::string  attribs;
      antlr4::misc::Interval source_interval;
    };

private:

    /// \brief typedef to distinguish vars from ios
    class t_inout_nfo : public t_var_nfo {
    public:
      bool nolatch = false;
    };

    /// \brief specialized info class for outputs
    class t_output_nfo : public t_var_nfo {
    public:
      bool combinational = false;
    };

    /// \brief base info about memory blocks
    class t_mem_nfo {
    public:
      std::string name;
      e_MemType   mem_type;
      t_type_nfo  type_nfo;
      int         table_size;
      bool        do_not_initialize = false;
      bool        no_input_latch    = false;
      bool        delayed           = false;
      std::string custom_template;
      int         line;
      std::vector<std::string> clocks;
      std::vector<std::string> in_vars;
      std::vector<std::string> out_vars;
      std::vector<std::string> init_values;
      std::vector<std::string> members;
    };

    /// \brief holds a reference to the context responsible for a group definition
    class t_group_definition {
    public:
      siliceParser::GroupContext    *group           = nullptr; // from an actual group declaration
      siliceParser::IntrfaceContext *intrface        = nullptr; // from an interface declaration
      siliceParser::DeclarationMemoryContext *memory = nullptr; // from a memory declaration
      t_group_definition(siliceParser::GroupContext *g) : group(g)    {}
      t_group_definition(siliceParser::IntrfaceContext *i) : intrface(i) {}
      t_group_definition(siliceParser::DeclarationMemoryContext *m) : memory(m) {}
    };

    /// \brief inputs
    std::vector< t_inout_nfo  > m_Inputs;
    /// \brief outputs
    std::vector< t_output_nfo > m_Outputs;
    /// \brief inouts NOTE: can only be passed around
    std::vector< t_inout_nfo >  m_InOuts;
    /// \brief io groups
    std::unordered_map<std::string, t_group_definition> m_VIOGroups;
    /// \brief parameterized vars
    std::vector< std::string >  m_Parameterized;

    /// \brief all input names, map contains index in m_Inputs
    std::unordered_map<std::string, int > m_InputNames;
    /// \brief all output names, map contains index in m_Outputs
    std::unordered_map<std::string, int > m_OutputNames;
    /// \brief all inout names, map contains index in m_InOuts
    std::unordered_map<std::string, int > m_InOutNames;

    /// \brief VIO (variable-or-input-or-output) bound to module/algorithms outputs (wires) (vio name => wire name)
    std::unordered_map<std::string, std::string>  m_VIOBoundToModAlgOutputs;
    /// \brief module/algorithms inouts bound to VIO (inout => vio name)
    std::unordered_map<std::string, std::string > m_ModAlgInOutsBoundToVIO;

    /// \brief all variables
    std::vector< t_var_nfo >              m_Vars;
    /// \brief all var names, map contains index in m_Vars
    std::unordered_map<std::string, int > m_VarNames;

    /// \brief all memories
    std::vector< t_mem_nfo >              m_Memories;
    /// \brief all memorie names, map contains index in m_Memories
    std::unordered_map<std::string, int > m_MemoryNames;

    /// \brief enum binding direction
    enum e_BindingDir { e_Left, e_LeftQ, e_Right, e_BiDir, e_Auto, e_AutoQ };

    /// \brief records info about variable bindings
    typedef struct
    {
      std::string                    left;
      std::variant<std::string, siliceParser::IoAccessContext*> right;
      e_BindingDir dir;
      int          line;      // for error reporting
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
      std::unordered_map<std::string, std::pair<std::string, e_FFUsage> > boundinputs;
    } t_algo_nfo;

    /// \brief instanced algorithms
    std::unordered_map< std::string, t_algo_nfo > m_InstancedAlgorithms;
    std::vector< std::string >                    m_InstancedAlgorithmsInDeclOrder;

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

    /// \brief info about a call parameter
    /// 
    /// a group identifier
    /// expression is always the source expression (even if a group)
    typedef struct s_call_param  {
      antlr4::tree::ParseTree  *expression = nullptr;
      std::variant<
        std::monostate,                     // empty
        std::string,                        // identifier
        const t_group_definition*,          // group
        siliceParser::AccessContext*        // access
        > what;
    } t_call_param;

    /// \brief instanced modules
    std::unordered_map< std::string, t_module_nfo > m_InstancedModules;

    // forward definition
    class t_combinational_block;

    /// \brief stores info for single instructions
    class t_instr_nfo {
    public:
      t_combinational_block   *block = nullptr;
      antlr4::tree::ParseTree *instr = nullptr;
      int                       __id = -1;
      t_instr_nfo(antlr4::tree::ParseTree *instr_, t_combinational_block *block_, int __id_) : instr(instr_), block(block_), __id(__id_) {}
    };

    /// \brief subroutines
    class t_subroutine_nfo {
    public:
      std::string                                     name;
      t_combinational_block                          *top_block;
      std::unordered_set<std::string>                 allowed_reads;
      std::unordered_set<std::string>                 allowed_writes;
      std::unordered_map<std::string, std::string>    vios;     // [subroutine space => translated var name in host]
      std::vector<std::string>                        inputs;   // ordered list of input names (subroutine space)
      std::vector<std::string>                        outputs;  // ordered list of output names (subroutine space)
      std::vector<std::string>                        vars;     // ordered list of internal var names (subroutine space)
      std::unordered_map<std::string, int >           varnames; // internal var names (translated), for use with host m_Vars
      bool                                            contains_calls = false; // does the subroutine call other subroutines?
    };

    /// \brief all subroutines
    std::unordered_map< std::string, t_subroutine_nfo* > m_Subroutines;

    /// \brief typedef of data-structure storing subroutine return info
    typedef std::unordered_map< std::string, std::vector<std::pair<int, t_combinational_block *> > > t_SubroutinesCallerReturnStates;

    /// \brief forward declaration of a pipeline stage
    struct s_pipeline_stage_nfo;

    /// \brief info about a pipeline
    /// trickling protects globally written vios for later
    /// pipeline stages, so that the pipeline behaves as if 
    /// a standard loop.
    typedef struct {
      std::string                               name;
      std::unordered_map<std::string, v2i>      trickling_vios; // v2i: [0] stage at which to start [1] stage at which to stop
      std::vector<struct s_pipeline_stage_nfo*> stages;
    } t_pipeline_nfo;

    /// \brief info about a pipeline stage
    typedef struct s_pipeline_stage_nfo {
      t_pipeline_nfo *pipeline;
      int             stage_id;
    } t_pipeline_stage_nfo;

    /// \brief vector of all pipelines
    std::vector< t_pipeline_nfo* > m_Pipelines;

    /// \brief variable dependencies within combinational sequences
    class t_vio_dependencies {
    public:
      // records for each written variable so far, each variable it depends on (throughout all computations leading to it)
      std::unordered_map< std::string, std::unordered_set < std::string > > dependencies;
    };

    /// \brief variable dependencies within combinational sequences
    class t_vio_ff_usage {
    public:
      // records for each variable whether the D or Q port of a flip-flop is used
      std::unordered_map<std::string, e_FFUsage> ff_usage;
    };

    /// \brief ending actions for blocks
    class t_end_action {
    public:
      virtual ~t_end_action() {}
      virtual void getChildren(std::vector<t_combinational_block*>& _ch) const = 0;
      virtual std::string name() const = 0;
    };

    /// \brief goto a next block at the end
    class end_action_goto_next : public t_end_action
    {
    public:
      t_combinational_block        *next;
      end_action_goto_next(t_combinational_block *next_) : next(next_) {}
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(next); }
      std::string name() const override { return "end_action_goto_next";}
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
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(if_next); _ch.push_back(else_next); _ch.push_back(after); }
      std::string name() const override { return "end_action_if_else";}
    };

    /// \brief switch case at the end
    class end_action_switch_case : public t_end_action
    {
    public:
      bool                                                         onehot;
      t_instr_nfo                                                  test;
      std::vector<std::pair<std::string, t_combinational_block*> > case_blocks;
      t_combinational_block*                                       after;
      end_action_switch_case(bool is_onehot,t_instr_nfo test_, const std::vector<std::pair<std::string, t_combinational_block*> >& case_blocks_, t_combinational_block* after_)
        : onehot(is_onehot), test(test_), case_blocks(case_blocks_), after(after_) {}
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { for (auto b : case_blocks) { _ch.push_back(b.second); } _ch.push_back(after); }
      std::string name() const override { return "end_action_switch_case";}
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
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(iteration);  _ch.push_back(after); }
      std::string name() const override { return "end_action_while";}
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
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(waiting); _ch.push_back(next); }
      std::string name() const override { return "end_action_wait";}
    };

    /// \brief return from a block at the end
    class end_action_return_from : public t_end_action
    {
    private:
    std::string                            subroutine;    
    const t_SubroutinesCallerReturnStates& return_states;
    public:
      end_action_return_from(std::string subroutine_,const t_SubroutinesCallerReturnStates& return_states_) : subroutine(subroutine_), return_states(return_states_) { }
      void getChildren(std::vector<t_combinational_block*>& _ch) const override {  
        auto RS = return_states.find(subroutine);
        if (RS != return_states.end()) {
          for (auto caller_return : RS->second) {
            _ch.push_back(caller_return.second);
          }
        }        
      }
      std::string name() const override { return "end_action_return_from";}
    };

    /// \brief goto next with return
    class end_action_goto_and_return_to : public t_end_action
    {
    public:
      t_combinational_block          *go_to;
      t_combinational_block          *return_to;
      end_action_goto_and_return_to(t_combinational_block* go_to_, t_combinational_block *return_to_) : go_to(go_to_), return_to(return_to_) {  }
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(go_to); /*_ch.push_back(return_to); <= not added since it is not a following state*/ }
      std::string name() const override { return "end_action_goto_and_return_to";}
    };

    /// \brief pipeline with next
    class end_action_pipeline_next : public t_end_action
    {
    public:
      t_combinational_block        *next;
      t_combinational_block        *after;
      end_action_pipeline_next(t_combinational_block *next_, t_combinational_block *after_) : next(next_), after(after_) { }
      void getChildren(std::vector<t_combinational_block*>& _ch) const override { _ch.push_back(next); _ch.push_back(after); }
      std::string name() const override { return "end_action_pipeline_next";}
    };

    /// \brief counter to generate caller ids, used for subroutine returns
    int                                                             m_SubroutineCallerNextId = 0;
    /// \brief map of ids for each subroutine caller
    std::unordered_map< const end_action_goto_and_return_to *, int> m_SubroutineCallerIds;
    /// \brief subroutine calls: which states subroutine are going back to
    t_SubroutinesCallerReturnStates                                 m_SubroutinesCallerReturnStates;

    /// \brief combinational block context
    typedef struct s_combinational_block_context  {
      t_subroutine_nfo            *subroutine   = nullptr; // if block belongs to a subroutine
      t_pipeline_stage_nfo        *pipeline     = nullptr; // if block belongs to a pipeline
      const t_combinational_block *parent_scope = nullptr; // parent block in scope
      std::unordered_map<std::string, std::string> vio_rewrites; // if the block contains vio rewrites
    } t_combinational_block_context;

    /// \brief a combinational block of code
    class t_combinational_block
    {
    private:
      void swap_end(t_end_action *end) { if (end_action != nullptr) delete (end_action); end_action = end; }
    public:
      size_t                              id;                   // internal block id
      std::string                         block_name;           // internal block name (state name from source when applicable)
      antlr4::misc::Interval              source_interval = antlr4::misc::Interval::INVALID; // block source interval
      bool                                is_state = false;     // true if block has to be a state, false otherwise
      bool                                is_sub_state = false; // true if block is a sub state in a linear seauence
      bool                                could_be_sub = false; // whether could be made a sub-state
      bool                                no_skip = false;      // true the state cannot be skipped, even if empty
      int                                 state_id = -1;        // state id, when assigned, -1 otherwise
      int                                 parent_state_id = -1; // state id of the parent, -1 only if never reached
      int                                 num_sub_states = 0;   // number of sub-states below if root of a sequence
      int                                 sub_state_id = 0;     // sub-state id if is_sub_state
      std::vector<t_instr_nfo>            instructions;         // list of instructions within block
      t_end_action                       *end_action = nullptr; // end action to perform
      t_combinational_block_context       context;              // block context: subroutine, parent, etc.
      std::unordered_set<std::string>     declared_vios;        // vios declared by block
      std::unordered_map<std::string, int> initialized_vars;     // variables to initialize at block start
      std::unordered_set<std::string>     in_vars_read;         // which variables are read from before
      std::unordered_set<std::string>     out_vars_written;     // which variables have been written after
      ~t_combinational_block() { swap_end(nullptr); }

      std::string end_action_name() { if (end_action != nullptr) return end_action->name(); else return "<none>"; }

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

      void switch_case(bool is_onehot,t_instr_nfo test, const std::vector<std::pair<std::string, t_combinational_block*> >& case_blocks, t_combinational_block* after)
      {
        swap_end(new end_action_switch_case(is_onehot,test, case_blocks, after));
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

      void return_from(std::string subroutine,const t_SubroutinesCallerReturnStates& return_states)
      {
        swap_end(new end_action_return_from(subroutine,return_states));
      }
      const end_action_return_from *return_from() const { return dynamic_cast<const end_action_return_from*>(end_action); }

      void goto_and_return_to(t_combinational_block* go_to, t_combinational_block *return_to)
      {
        swap_end(new end_action_goto_and_return_to(go_to, return_to));
      }
      const end_action_goto_and_return_to * goto_and_return_to() const { return dynamic_cast<const end_action_goto_and_return_to*>(end_action); }

      void pipeline_next(t_combinational_block *next, t_combinational_block *after)
      {
        swap_end(new end_action_pipeline_next(next, after));
      }
      const end_action_pipeline_next *pipeline_next() const { return dynamic_cast<const end_action_pipeline_next*>(end_action); }

      void getChildren(std::vector<t_combinational_block*>& _ch) const { if (end_action != nullptr) end_action->getChildren(_ch); }
    };

    /// \brief context while gathering code
    typedef struct
    {
      int                    __id;
      t_combinational_block *break_to;
    } t_gather_context;

    /// \brief information about a forward jump
    typedef struct {
      t_combinational_block     *from;
      antlr4::ParserRuleContext *jump;
    } t_forward_jump;

    /// \brief always blocks
    t_combinational_block                                             m_AlwaysPre;
    t_combinational_block                                             m_AlwaysPost;
    /// \brief wire assignments
    std::unordered_map<std::string,t_instr_nfo>                       m_WireAssignments;
    /// \brief all combinational blocks
    std::list< t_combinational_block* >                               m_Blocks;
    /// \brief state name to combinational block
    std::unordered_map< std::string, t_combinational_block* >         m_State2Block;
    /// \brief id to combination block
    std::unordered_map< size_t, t_combinational_block* >              m_Id2Block;
    /// \brief stores encountered forwards refs for later resolution
    std::unordered_map< std::string, std::vector< t_forward_jump > >  m_JumpForwardRefs;
    /// \brief maximum state value of the algorithm
    int m_MaxState      = -1;
    /// \brief integer name of the next block
    int m_NextBlockName = 1;
    /// \brief indicates whether this algorithm is the topmost in the design
    bool m_TopMost      = false;
    /// \brief indicates whether a VIO report has to be generated and what the filename is (empty means none)
    std::string m_VIOReportName;
    /// \brief indicates whether a FSM report has to be generated and what the filename is (empty means none)
    std::string m_FSMReportName;
    /// \brief internally set to true when the report has to be written
    bool        m_FSMReportEnable;

  public:

    /// \brief information about instantiation (public for linter)
    typedef struct {
      std::unordered_map<std::string, std::string> parameters;
    } t_instantiation_context;

  private:

    /// \brief returns true if belongs to inputs
    bool isInput(std::string var) const;
    /// \brief returns true if belongs to outputs
    bool isOutput(std::string var) const;
    /// \brief returns true if belongs to inouts
    bool isInOut(std::string var) const;
    /// \brief checks whether an identifier is an input or output
    bool isInputOrOutput(std::string var) const;
    /// \brief checks whether an identifier is a VIO
    bool isVIO(std::string var) const;
    /// \brief returns a VIO definition
    t_var_nfo getVIODefinition(std::string var, bool &_found) const;
    /// \brief variant of above (historical reasons, TODO: cleanup)
    bool getVIONfo(std::string vio, t_var_nfo &_nfo) const;
    /// \brief checks whether an identifier is a group VIO
    bool isGroupVIO(std::string var) const;
    /// \brief rewrites a constant
    std::string rewriteConstant(std::string cst) const;
    /// \brief returns a string representing the widthof value
    std::string resolveWidthOf(std::string vio, antlr4::misc::Interval interval) const;
    /// \brief adds a combinational block to the list of blocks, performs book keeping
    template<class T_Block = t_combinational_block>
    t_combinational_block *addBlock(std::string name, const t_combinational_block *parent, const t_combinational_block_context *bctx = nullptr, antlr4::misc::Interval interval = antlr4::misc::Interval::INVALID);
    /// \brief resets the block name generator
    void resetBlockName();
    /// \brief generate the next block name
    std::string generateBlockName();
    /// \brief returns the bitfield width
    int bitfieldWidth(siliceParser::BitfieldContext* field) const;
    /// \brief returns the bitfield member type and offset and width
    std::pair<t_type_nfo, int> bitfieldMemberTypeAndOffset(siliceParser::BitfieldContext* field, std::string member) const;
    /// \brief gather a const value
    std::string gatherConstValue(siliceParser::ConstValueContext *ival) const;
    /// \brief gather a bitfield value
    std::string gatherBitfieldValue(siliceParser::InitBitfieldContext* ival);
    /// \brief gather a value
    std::string gatherValue(siliceParser::ValueContext* ival);
    /// \brief insert a variable in the data-structures (lower level than addVar, use to insert any var), return the index in m_Vars of the inserted var
    void insertVar(const t_var_nfo &_var, t_combinational_block *_current, bool no_init = false);
    /// \brief add a variable from its definition (_var may be modified with an updated name)
    void addVar(t_var_nfo& _var, t_combinational_block *_current, t_gather_context *_context, antlr4::misc::Interval interval = antlr4::misc::Interval::INVALID);
    /// \brief check if an identifier is available
    bool isIdentifierAvailable(std::string name) const;
    /// \brief gather type nfo
    void gatherTypeNfo(siliceParser::TypeContext *type,t_type_nfo &_nfo, t_combinational_block *_current, t_gather_context *_context, std::string& _is_group);
    /// \brief gather wire declaration
    void gatherDeclarationWire(siliceParser::DeclarationWireContext* decl, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather variable nfo
    void gatherVarNfo(siliceParser::DeclarationVarContext *decl, t_var_nfo &_nfo, bool default_no_init, t_combinational_block *_current, t_gather_context *_context,std::string& _is_group);
    /// \brief gather variable declaration
    void gatherDeclarationVar(siliceParser::DeclarationVarContext* decl, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather all values from an init list
    void gatherInitList(siliceParser::InitListContext* ilist, std::vector<std::string>& _values_str);
    /// \brief gather all values from a file
    void gatherInitListFromFile(int width, siliceParser::InitListContext *ilist, std::vector<std::string> &_values_str);
    /// \bried read initializer list
    template<typename D, typename T> void readInitList(D* decl, T& var);
    /// \brief gather table nfo
    void gatherTableNfo(siliceParser::DeclarationTableContext *decl, t_var_nfo &_nfo, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather variable declaration
    void gatherDeclarationTable(siliceParser::DeclarationTableContext* decl, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather memory declaration
    void gatherDeclarationMemory(siliceParser::DeclarationMemoryContext* decl, t_combinational_block *_current, t_gather_context *_context);
    /// \brief extract the list of bindings
    void getBindings(
      siliceParser::ModalgBindingListContext *bindings,
      std::vector<t_binding_nfo>& _vec_bindings,
      bool& _autobind) const;
    /// \brief gather group declaration
    void gatherDeclarationGroup(siliceParser::DeclarationGrpModAlgContext* grp, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather algorithm declaration
    void gatherDeclarationAlgo(siliceParser::DeclarationGrpModAlgContext* alg, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather module declaration
    void gatherDeclarationModule(siliceParser::DeclarationGrpModAlgContext* mod, t_combinational_block *_current, t_gather_context *_context);
    /// \brief expands the name of a subroutine vio
    std::string subroutineVIOName(std::string vio, const t_subroutine_nfo *sub);
    /// \brief expands the name of a block vio
    std::string blockVIOName(std::string vio, const t_combinational_block *host);
    /// \brief returns the name of a trickling vio for a stage of a piepline
    std::string tricklingVIOName(std::string vio, const t_pipeline_nfo *nfo, int stage) const;
    /// \brief returns the name of a trickling vio for a stage of a piepline
    std::string tricklingVIOName(std::string vio, const t_pipeline_stage_nfo *nfo) const;
    /// \brief translate a variable name using subroutine/pipeline info
    std::string translateVIOName(std::string vio, const t_combinational_block_context *bctx) const;
    /// \brief Ecanpsulates the identifier in whatever is required after rewrite
    std::string encapsulateIdentifier(std::string var, bool read_access, std::string rewritten, std::string suffix) const;
    /// \brief returns the rewritten indentifier, taking into account bindings, inputs/outputs, custom clocks and resets
    std::string rewriteIdentifier(
      std::string prefix, std::string var, std::string suffix,
      const t_combinational_block_context *bctx, size_t line,
      std::string ff, bool read_access,
      const t_vio_dependencies &dependencies, 
      t_vio_ff_usage &_ff_usage, e_FFUsage ff_force = e_None) const;
    /// \brief rewrite an expression, renaming identifiers
    std::string rewriteExpression(std::string prefix, antlr4::tree::ParseTree *expr, int __id, const t_combinational_block_context* bctx, std::string ff, bool read_access, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief returns true if an expression is a single identifier
    bool isIdentifier(antlr4::tree::ParseTree *expr, std::string& _identifier) const;
    /// \brief returns true if an expression is an access
    bool isAccess(antlr4::tree::ParseTree *expr, siliceParser::AccessContext*& _access) const;
    /// \brief split current block (state present) or continue current with the next instruction list
    t_combinational_block *splitOrContinueBlock(siliceParser::InstructionListContext* ilist, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a break from loop
    t_combinational_block *gatherBreakLoop(siliceParser::BreakLoopContext* brk, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a while block
    t_combinational_block *gatherWhile(siliceParser::WhileLoopContext* loop, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather declaration
    void gatherDeclaration(siliceParser::DeclarationContext *decl, t_combinational_block *_current, t_gather_context *_context, bool var_group_table_only);
    /// \brief gather declaration list, returns number of gathered declarations 
    int gatherDeclarationList(siliceParser::DeclarationListContext* decllist, t_combinational_block *_current, t_gather_context *_context, bool var_group_table_only);
    /// \brief gather a subroutine
    t_combinational_block *gatherSubroutine(siliceParser::SubroutineContext* sub, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a pipeline
    t_combinational_block *gatherPipeline(siliceParser::PipelineContext* pip, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a jump
    t_combinational_block* gatherJump(siliceParser::JumpContext* jump, t_combinational_block* _current, t_gather_context* _context);
    /// \brief gather a circuitry instanciation
    t_combinational_block* gatherCircuitryInst(siliceParser::CircuitryInstContext* ci, t_combinational_block* _current, t_gather_context* _context);
    /// \brief gather a return
    t_combinational_block* gatherReturnFrom(siliceParser::ReturnFromContext* ret, t_combinational_block* _current, t_gather_context* _context);
    /// \brief gather a synchronous execution
    t_combinational_block* gatherSyncExec(siliceParser::SyncExecContext* sync, t_combinational_block* _current, t_gather_context* _context);
    /// \brief gather a join execution
    t_combinational_block *gatherJoinExec(siliceParser::JoinExecContext* join, t_combinational_block *_current, t_gather_context *_context);
    /// \brief tests whether a graph of block is stateless
    bool isStateLessGraph(t_combinational_block *head) const;
    /// \brief find all non-comibnation leaves from this block
    void findNonCombinationalLeaves(const t_combinational_block *head,std::set<t_combinational_block*>& _leaves) const;
    /// \brief gather an if-then-else
    t_combinational_block *gatherIfElse(siliceParser::IfThenElseContext* ifelse, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather an if-then
    t_combinational_block *gatherIfThen(siliceParser::IfThenContext* ifthen, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a switch-case
    t_combinational_block* gatherSwitchCase(siliceParser::SwitchCaseContext* switchCase, t_combinational_block* _current, t_gather_context* _context);
    /// \brief gather a repeat block
    t_combinational_block *gatherRepeatBlock(siliceParser::RepeatBlockContext* repeat, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather always assigned
    void gatherAlwaysAssigned(siliceParser::AlwaysAssignedListContext* alws, t_combinational_block *always);
    ///\brief Runs the linter on the algorithm, at instantiation time
    void lint(const t_instantiation_context &ictx);
    /// \brief check access permissions (recursively) from a specific node
    void checkPermissions(antlr4::tree::ParseTree *node, t_combinational_block *_current);
    /// \brief check access permissions on all block instructions
    void checkPermissions();
    /// \brief check expressions (recursively) from node
    void checkExpressions(const t_instantiation_context &ictx,antlr4::tree::ParseTree *node, const t_combinational_block *_current);
    /// \brief check expressions on all blocks
    void checkExpressions(const t_instantiation_context &ictx);
    /// \brief Verifies validity of bindings on instanced modules
    void checkModulesBindings() const;
    /// \brief Verifies validity of bindings on instanced algorithms
    void checkAlgorithmsBindings(const t_instantiation_context &ictx) const;
    /// \brief gather info about an input
    void gatherInputNfo(siliceParser::InputContext* input, t_inout_nfo& _io, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather info about an output
    void gatherOutputNfo(siliceParser::OutputContext* input, t_output_nfo& _io, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather info about an inout
    void gatherInoutNfo(siliceParser::InoutContext* inout, t_inout_nfo& _io);
    /// \brief gather infos about an io definition (group/interface)
    void gatherIoDef(siliceParser::IoDefContext *iod, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather infos about an io group
    void gatherIoGroup(siliceParser::IoDefContext * iog, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather infos about an io interface
    void gatherIoInterface(siliceParser::IoDefContext *itrf);
    /// \brief gather inputs and outputs
    void gatherIOs(siliceParser::InOutListContext* inout, t_combinational_block *_current, t_gather_context *_context);
    /// \brief gather a block
    t_combinational_block *gatherBlock(siliceParser::BlockContext *block, t_combinational_block *_current, t_gather_context *_context);
    /// \brief extract the ordered list of parameters for calling an algorithm or subroutine (call and return)
    void getCallParams(siliceParser::CallParamListContext* params, std::vector<t_call_param>& _inparams, const t_combinational_block_context* bctx) const;
    /// \brief match parameters between a given list and the expected list, expanding groups
    bool matchCallParams(const std::vector<t_call_param>& given_params, const std::vector<std::string>& expected_params, const t_combinational_block_context* bctx, std::vector<t_call_param>& _matches) const;
    /// \brief parse call parameters for an algorithm
    void parseCallParams(siliceParser::CallParamListContext *params, const Algorithm *alg, bool input_else_output, const t_combinational_block_context *bctx, std::vector<t_call_param> &_matches) const;
    /// \brief parse call parameters for a subroutine
    void parseCallParams(siliceParser::CallParamListContext *params, const t_subroutine_nfo *sub, bool input_else_output, const t_combinational_block_context *bctx, std::vector<t_call_param> &_matches) const;
    /// \brief extract the ordered list of identifiers
    void getIdentifiers(siliceParser::IdentifierListContext* idents, std::vector<std::string>& _vec_params, const t_combinational_block_context* bctx) const;
    /// \brief sematic parsing, first discovery pass
    t_combinational_block *gather(antlr4::tree::ParseTree *tree, t_combinational_block *_current, t_gather_context *_context);
    /// \brief resolves forward references for jumps
    void resolveForwardJumpRefs();
    /// \brief generates the states for the entire algorithm
    void generateStates();
    /// \brief returns the max state value of the algorithm
    int maxState() const;
    /// \brief returns the index of the entry state
    int entryState() const;
    /// \brief returns the index to jump to to intitate the termination sequence
    int terminationState() const;
    /// \brief returns the state bit-width required to encode up to max_state
    int width(int max_state) const;
    /// \brief returns the state bit-width for the algorithm
    int stateWidth() const;
    /// \brief fast-forward to the next non empty state
    const t_combinational_block *fastForward(const t_combinational_block *block) const;
    /// \brief verify member in group
    void verifyMemberGroup(std::string member, siliceParser::GroupContext* group, int line) const;
    /// \brief verify member in interface
    void verifyMemberInterface(std::string member, siliceParser::IntrfaceContext *intrface, int line) const;
    /// \brief verify member in group definition
    void verifyMemberGroup(std::string member, const t_group_definition& gd, int line) const;
    /// \brief get the list of members within a group
    std::vector<std::string> getGroupMembers(const t_group_definition &gd) const;
    /// \brief verify member in bitfield
    void verifyMemberBitfield(std::string member, siliceParser::BitfieldContext* group, int line) const;
    /// \brief report an error
    void reportError(antlr4::Token* what, int line, const char *msg, ...) const;
    void reportError(antlr4::misc::Interval interval, int line, const char *msg, ...) const;
    /// \brief Pre-processor, optionally set
    static LuaPreProcessor *s_LuaPreProcessor;

  private:

    /// \brief update and check variable dependencies for an instruction
    void updateAndCheckDependencies(t_vio_dependencies& _depds, antlr4::tree::ParseTree* instr, const t_combinational_block_context* bctx) const;
    /// \brief merge variable dependencies
    void mergeDependenciesInto(const t_vio_dependencies& _depds0, t_vio_dependencies& _depds) const;
    /// \brief update flip-flop usage
    void updateFFUsage(e_FFUsage usage, bool read_access, e_FFUsage &_ff) const;
    /// \brief combine flip-flop usage
    void combineFFUsageInto(const t_combinational_block *debug_block,const t_vio_ff_usage &ff_before, std::vector<t_vio_ff_usage> &ff_branches, t_vio_ff_usage& _ff_after) const;
    /// \brief clear no latch from FF usage
    void clearNoLatchFFUsage(t_vio_ff_usage &_ff) const;
    /// \brief determine binding right identifier
    std::string bindingRightIdentifier(const t_binding_nfo& bnd, const t_combinational_block_context* bctx = nullptr) const;
    /// \brief determine accessed variable
    std::string determineAccessedVar(siliceParser::AccessContext* access, const t_combinational_block_context* bctx) const;
    std::string determineAccessedVar(siliceParser::IoAccessContext* access, const t_combinational_block_context* bctx) const;
    std::string determineAccessedVar(siliceParser::BitAccessContext* access, const t_combinational_block_context* bctx) const;
    std::string determineAccessedVar(siliceParser::BitfieldAccessContext* access, const t_combinational_block_context* bctx) const;
    std::string determineAccessedVar(siliceParser::TableAccessContext* access, const t_combinational_block_context* bctx) const;
    /// \brief determine variables/inputs/outputs access within an instruction (from its tree)
    void determineVIOAccess(
      antlr4::tree::ParseTree*                    node,
      const std::unordered_map<std::string, int>& vios,
      const t_combinational_block_context        *bctx,
      std::unordered_set<std::string>& _read, std::unordered_set<std::string>& _written) const;
    /// \brief determine variables written outside of pipeline
    void determineOutOfPipelineAssignments(
      antlr4::tree::ParseTree *node,
      const std::unordered_map<std::string, int> &vios,
      const t_combinational_block_context *bctx,
      std::unordered_set<std::string> &_ex_written,std::unordered_set<std::string> &_not_ex_written) const;
    /// \brief updates access to vars due to a binding
    template<typename T_nfo>
    void updateAccessFromBinding(const t_binding_nfo& b, const std::unordered_map<std::string, int > &names, std::vector< T_nfo > &_nfos);
    /// \brief determines variable access for an instruction
    void determineVariablesAndOutputsAccess(
      antlr4::tree::ParseTree             *instr,
      const t_combinational_block_context *context,
      std::unordered_set<std::string> &_already_written, 
      std::unordered_set<std::string> &_in_vars_read,
      std::unordered_set<std::string> &_out_vars_written);
    /// \brief determines variable access within a block
    void determineVariablesAndOutputsAccess(t_combinational_block *block);
    /// \brief determine variable access due to wires within the algorithm
    void determineVariablesAndOutputsAccessForWires(
      std::unordered_set<std::string> &_global_in_read,
      std::unordered_set<std::string> &_global_out_written
    );
    /// \brief determine variable access within the algorithm
    void determineVariablesAndOutputsAccess(
      std::unordered_set<std::string> &_global_in_read,
      std::unordered_set<std::string> &_global_out_written
    );
    /// \brief analyze variables access and classifies variables
    void determineVariableAndOutputsUsage();
    /// \brief determines the list of bound VIO
    void determineModAlgBoundVIO();
    /// \brief analyze the subroutine calls
    void analyzeSubroutineCalls();
    /// \brief analyze usage of inputs of instanced algorithms
    void analyzeInstancedAlgorithmsInputs();
    /// \brief autobind algorithm
    void autobindInstancedAlgorithm(t_algo_nfo& _alg);
    /// \brief autobind a module
    void autobindInstancedModule(t_module_nfo& _mod);
    /// \brief resove e_Auto binding directions
    void resolveInstancedAlgorithmBindingDirections(t_algo_nfo& _alg);
    /// \brief returns true if the algorithm does not have an FSM
    bool hasNoFSM() const;
    /// \brief returns true if the algorithm does not need a reset
    bool requiresNoReset() const;
    /// \brief returns true if the algorithm does not call subroutines
    bool doesNotCallSubroutines() const;
    /// \brief returns true if the algorithm is not callable
    bool isNotCallable() const;
    /// \brief converts an internal state into a FSM state
    int  toFSMState(int state) const;
    /// \brief finds the binding to var
    const t_binding_nfo &findBindingTo(std::string var, const std::vector<t_binding_nfo> &bndgs, bool &_found) const;

  public:

    /// \brief constructor
    Algorithm(
      std::string name,
      std::string clock, std::string reset,
      bool autorun, bool onehot,
      const std::unordered_map<std::string, AutoPtr<Module> >&                 known_modules,
      const std::unordered_map<std::string, siliceParser::SubroutineContext*>& known_subroutines,
      const std::unordered_map<std::string, siliceParser::CircuitryContext*>&  known_circuitries,
      const std::unordered_map<std::string, siliceParser::GroupContext*>&      known_groups,
      const std::unordered_map<std::string, siliceParser::IntrfaceContext *>& known_interfaces,
      const std::unordered_map<std::string, siliceParser::BitfieldContext*>&   known_bitfield);
    /// \brief destructor
    virtual ~Algorithm();

    /// \brief sets the input parsed tree
    void gather(siliceParser::InOutListContext *inout, antlr4::tree::ParseTree *declAndInstr);

    /// \brief resolve instanced modules refs
    void resolveModuleRefs(const std::unordered_map<std::string, AutoPtr<Module> >& modules);
    /// \brief resolve instanced algorithms refs
    void resolveAlgorithmRefs(const std::unordered_map<std::string, AutoPtr<Algorithm> >& algorithms);
    /// \brief run optimizations
    void optimize();

  private:

    /// \brief returns variable bit range for verilog declaration
    std::string varBitRange(const t_var_nfo& v, const t_instantiation_context &ictx) const;
    /// \brief returns a variable bit width for verilog use
    std::string varBitWidth(const t_var_nfo &v, const t_instantiation_context &ictx) const;
    /// \brief returns a variable init value for verilog use (non-tables only)
    std::string varInitValue(const t_var_nfo &v, const t_instantiation_context &ictx) const;
    /// \brief returns the base type of a variable
    e_Type      varType     (const t_var_nfo& v, const t_instantiation_context &ictx) const;
    /// \brief returns a type dependent string for resource declaration
    std::string typeString(e_Type type) const;
    /// \brief finds the root of a same_as chain
    std::string findSameAsRoot(std::string vio, const t_combinational_block_context *bctx) const;
    /// \brief write a verilog wire/reg declaration, possibly parameterized
    void writeVerilogDeclaration(std::ostream &out, const t_instantiation_context &ictx, std::string base, const t_var_nfo &v, std::string postfix) const;
    /// \brief determines vio bit width and (if applicable) table size
    std::tuple<t_type_nfo, int> determineVIOTypeWidthAndTableSize(const t_combinational_block_context *bctx, std::string vname, antlr4::misc::Interval interval, int line) const;
    /// \brief determines identifier bit width and (if applicable) table size
    std::tuple<t_type_nfo, int> determineIdentifierTypeWidthAndTableSize(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, antlr4::misc::Interval interval, int line) const;
    /// \brief determines identifier type and width
    t_type_nfo determineIdentifierTypeAndWidth(const t_combinational_block_context *bctx, antlr4::tree::TerminalNode *identifier, antlr4::misc::Interval interval, int line) const;
    /// \brief determines bitfield access bit width
    t_type_nfo determineBitfieldAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::BitfieldAccessContext *ioaccess) const;
    /// \brief determines IO access bit width
    t_type_nfo determineIOAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::IoAccessContext *ioaccess) const;
    /// \brief determines bit access type/width
    t_type_nfo determineBitAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::BitAccessContext *bitaccess) const;
    /// \brief determines table access type/width
    t_type_nfo determineTableAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::TableAccessContext *tblaccess) const;
    /// \brief determines access type/width
    t_type_nfo determineAccessTypeAndWidth(const t_combinational_block_context *bctx, siliceParser::AccessContext *access, antlr4::tree::TerminalNode *identifier) const;
    /// \brief writes a call to an algorithm
    void writeAlgorithmCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::CallParamListContext *plist, const t_combinational_block_context *bctx, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes reading back the results of an algorithm
    void writeAlgorithmReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_algo_nfo& a, siliceParser::CallParamListContext *plist, const t_combinational_block_context *bctx, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes a call to a subroutine
    void writeSubroutineCall(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo* called, const t_combinational_block_context* bctx, siliceParser::CallParamListContext *plist, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes reading back the results of a subroutine
    void writeSubroutineReadback(antlr4::tree::ParseTree *node, std::string prefix, std::ostream& out, const t_subroutine_nfo* called, const t_combinational_block_context* bctx, siliceParser::CallParamListContext *plist, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes access to an algorithm in/out, memory or group member ; returns info of accessed member.
    std::tuple<t_type_nfo, int> writeIOAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::IoAccessContext* ioaccess, std::string suffix, int __id, const t_combinational_block_context* bctx, std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes access to a table in/out
    void writeTableAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::TableAccessContext* tblaccess, std::string suffix, int __id, const t_combinational_block_context* bctx, std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes access to a bitfield member
    void writeBitfieldAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitfieldAccessContext* ioaccess, int __id, const t_combinational_block_context* bctx, std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes access to bits
    void writeBitAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::BitAccessContext* bitaccess, int __id, const t_combinational_block_context *bctx, std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes access to an identifier
    void writeAccess(std::string prefix, std::ostream& out, bool assigning, siliceParser::AccessContext* access, int __id, const t_combinational_block_context *bctx, std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes an assignment
    void writeAssignement(std::string prefix, std::ostream& out,
      const t_instr_nfo& a,
      siliceParser::AccessContext *access,
      antlr4::tree::TerminalNode* identifier,
      siliceParser::Expression_0Context *expression_0,
      const t_combinational_block_context *bctx,
      std::string ff, const t_vio_dependencies& dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes all wire assignements
    void writeWireAssignements(std::string prefix, std::ostream &out, t_vio_dependencies &_dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes flip-flop value update for a variable
    void writeVarFlipFlopUpdate(std::string prefix, std::string reset, std::ostream& out, const t_instantiation_context &ictx, const t_var_nfo& v) const;
    /// \brief writes the const declarations
    void writeConstDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const;
    /// \brief writes the temporary declarations
    void writeTempDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const;
    /// \brief writes the wire declarations
    void writeWireDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const;
    /// \brief writes the flip-flop declarations
    void writeFlipFlopDeclarations(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const;
    /// \brief writes the flip-flops
    void writeFlipFlops(std::string prefix, std::ostream& out, const t_instantiation_context &ictx) const;
    /// \brief writes flip-flop combinational value update for a variable
    void writeVarFlipFlopCombinationalUpdate(std::string prefix, std::ostream& out, const t_var_nfo& v) const;
    /// \brief add a state to the queue
    void pushState(const t_combinational_block *b, std::queue<size_t> &_q) const;
    /// \brief writes combinational steps that are always performed /before/ the state machine
    void writeCombinationalAlwaysPre(std::string prefix, std::ostream& out, const t_instantiation_context &ictx, t_vio_dependencies& _always_dependencies, t_vio_ff_usage &_ff_usage, t_vio_dependencies &_post_dependencies) const;
    /// \brief writes all states in the output
    void writeCombinationalStates(std::string prefix, std::ostream &out, const t_instantiation_context &ictx, const t_vio_dependencies &always_dependencies, t_vio_ff_usage &_ff_usage, t_vio_dependencies &_post_dependencies) const;
    /// \brief writes a graph of stateless blocks to the output, until a jump to other states is reached
    void writeStatelessBlockGraph(std::string prefix, std::ostream& out, const t_instantiation_context &ictx, const t_combinational_block* block, const t_combinational_block* stop_at, std::queue<size_t>& _q, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage, t_vio_dependencies &_post_dependencies) const;
    /// \brief writes a stateless pipeline to the output, returns zhere to resume from
    const t_combinational_block *writeStatelessPipeline(std::string prefix, std::ostream& out, const t_instantiation_context &ictx, const t_combinational_block* block_before, std::queue<size_t>& _q, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage, t_vio_dependencies &_post_dependencies) const;
    /// \brief writes a single block to the output
    void writeBlock(std::string prefix, std::ostream &out, const t_instantiation_context &ictx, const t_combinational_block *block, t_vio_dependencies &_dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes variable inits
    void writeVarInits(std::string prefix, std::ostream& out, const t_instantiation_context &ictx, const std::unordered_map<std::string, int >& varnames, t_vio_dependencies& _dependencies, t_vio_ff_usage &_ff_usage) const;
    /// \brief writes a memory module
    void writeModuleMemory(std::string instance_name, std::ostream& out, const t_mem_nfo& mem) const;
    /// \brief returns the name of a memory module instance
    std::string memoryModuleName(std::string instance_name, const t_mem_nfo &bram) const;
    /// \brief prepare replacements for a memory module template
    void prepareModuleMemoryTemplateReplacements(std::string instance_name, const t_mem_nfo& bram, std::unordered_map<std::string, std::string>& _replacements) const;
    /// \brief writes the algorithm as a Verilog module, recurses through instanced algorithms
    void writeAsModule(std::string instance_name, std::ostream &out, const t_instantiation_context &ictx, bool first_pass);
    /// \brief writes the algorithm as a Verilog module, calls the version above twice in a two pass optimization process
    void writeAsModule(std::string instance_name, std::ostream &out, const t_instantiation_context& ictx, t_vio_ff_usage &_ff_usage, bool do_lint) const;
    /// \brief outputs a report on the VIOs in the algorithm
    void outputVIOReport(std::string instance_name, const t_instantiation_context &ictx) const;

  public:

    /// \brief asks for a VIO report to be generated
    void enableVIOReport(std::string reportname);

    /// \brief asks for an FSM report to be generated
    void enableFSMReport(std::string reportname);

    /// \brief writes a topmost algorithm as a Verilog module, recurses through instanced algorithms
    void writeAsModule(std::string instance_name,std::ostream& out);

    /// \brief outputs the FSM graph in a file (graphviz dot format)
    void outputFSMGraph(std::string dotFile) const;

    /// \brief ExpressionLinter is a friend
    friend class ExpressionLinter;

    /// \brief return the algorithm name
    std::string name() const { return m_Name; }
  
    /// \brief set the pre-processor
    static void setLuaPreProcessor(LuaPreProcessor *lpp)
    {
      s_LuaPreProcessor = lpp;
    }

  };

  // -------------------------------------------------

};
