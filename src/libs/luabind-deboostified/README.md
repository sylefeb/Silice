luabind
=======
Currently, at least the following compilers are supported:
- MSVC 2013 Update 3
- Clang/LLVM 3.6.0
- G++ 4.9

If you can confirm support on another platform, please let me know!

Create Lua bindings for your C++ code easily - my improvements
- Variadic templates.
- Got rid of the arrays created in invoke.
- All boost removed.
- No backward compatibility to any old or faulty (MS) compilers.
- This is 24mb of Intellisense db versus close to 90mb with original luabind, also Intellisense is not crippled by boost preprocessor usage.

**Important**: This is not drop in replacable.
- The template parameters to class class_ work a bit differently to the original (Wrapper and Holder have a specific index, if you don't want one of them, use null_type and/or no_bases)
- The policies are not implemented as functions with a wrapped integer argument, they're aliases to policy lists containing exactly the one respective policy
- The error callback is no longer the function that is pushed as pcall's error handler, but is instead called to push the error handler onto the stack
- Exceptions thrown by luabind will now carry the error message, it no longer has to be pulled from the lua stack separately
- Since the requirement to Boost.Optional has been dropped, object_cast_nothrow now has a mandatory default argument that is returned when the cast failed. Use boost::optional<T>() for that to get the old behavior
