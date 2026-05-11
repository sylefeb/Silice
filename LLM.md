# About LLM usage in this repository

The Silice compiler (`src/`) is carefully hand-written and will remain so.

Overall the usage of LLMs in the repo has to remain minimal and reserved to
assist with tedious tasks (1). In such cases the content is manually reviewed
with a contributor taking responsibility for it.

In each instance, this is indicated at the top of the file (or function if
applicable) by a comment saying:

```
// LLM assisted code
// Reviewed / edited by ...
```
(comment syntax to be adjusted based on language)

> (1) An example is the conversion into Lua pre-processor scripts of the
> PLL generators icepll, ecppll, etc.
