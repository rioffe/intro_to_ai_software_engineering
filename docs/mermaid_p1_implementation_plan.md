# Mermaid P1 Diagrams Implementation Plan

## Implementation Approach

- **Location**: In-place within chapter files where sections are referenced
- **Strategy**: Duplicate diagrams where referenced (no central source)
- **Verification**: Test using existing `tools/build-book-html.sh` with mermaid-filter
- **Scope**: All 19 P1 diagrams across 12 chapters

## P1 Diagrams to Implement

| Chapter | File | Section | Type | Description |
| --------- | ------ | --------- | ------ | ------------- |
| 0 | `00-front-matter.md` | "What 'Hybrid' Means" | `flowchart TD` | Hybrid boundary diagram |
| 0 | `01-orientation.md` | 0.3.3 | `flowchart LR` | Git core loop |
| 1 | `02-meet-your-coding-agent.md` | 1.5.1 | `flowchart LR` | Agent stack |
| 1 | `02-meet-your-coding-agent.md` | 1.6 | `flowchart TD` | Review loop (cycle) |
| 2 | `03-writing-spec.md` | 2.2.3 | `flowchart LR` | Three altitudes |
| 4 | `05-fixed-mortgages.md` | 4.3 | `flowchart LR` | Four core quantities |
| 4 | `05-fixed-mortgages.md` | 4.4.2 | `flowchart TD` | Two directions derivation |
| 5 | `06-tests-and-tdd.md` | 5.2.1 | `stateDiagram-v2` | TDD cycle |
| 6 | `07-math-core-library.md` | 6.5.1 | `flowchart TD` | core.py call graph |
| 7 | `08-validation.md` | 7.7.1 | `flowchart LR` | Layered architecture |
| 8 | `09-cli.md` | 8.4.1 | `flowchart TD` | CLI pipeline |
| 9 | `10-calculator-ui.md` | 9.3.4 | `flowchart LR` | Signals and slots |
| 10 | `11-tool-interface.md` | 10.3.2 | `flowchart TD` | Tool definition anatomy |
| 10 | `11-tool-interface.md` | 10.5.1 | `flowchart TD` | call_tool never raises |
| 11 | `12-llm-interface.md` | 11.4.1 | `sequenceDiagram` | Tool-calling loop |
| 11 | `12-llm-interface.md` | 11.9 | `flowchart TD` | Full hybrid system |
| 12 | `13-evaluation.md` | 12.5.2 | `flowchart TD` | Eval harness |
| 13 | `14-hardening.md` | 13.4.2-13.4.3 | `flowchart TD` | Model-output decision tree |
| Closing | `15-closing.md` | C.2 | `flowchart TD` | Finished system |

## Build & Verification Notes

- Build note comment required after each mermaid block
- Use `flowchart LR` for two-to-four-stage pipelines
- Use `flowchart TD` for branching/longer flows
- Quote labels containing special characters
- Test both `make book` (PDF) and `make book.html` (HTML)

## Files to Edit

1. `manuscript/00-front-matter.md`
2. `manuscript/01-orientation.md`
3. `manuscript/02-meet-your-coding-agent.md`
4. `manuscript/03-writing-spec.md`
5. `manuscript/05-fixed-mortgages.md`
6. `manuscript/06-tests-and-tdd.md`
7. `manuscript/07-math-core-library.md`
8. `manuscript/08-validation.md`
9. `manuscript/09-cli.md`
10. `manuscript/10-calculator-ui.md`
11. `manuscript/11-tool-interface.md`
12. `manuscript/12-llm-interface.md`
13. `manuscript/13-evaluation.md`
14. `manuscript/14-hardening.md`
15. `manuscript/15-closing.md`

## Risk Considerations

- **version-sensitive diagrams**: None of the P1 diagrams use beta features
- **Line count**: Each diagram should stay within ~10-15 lines to avoid overflow
- **Build verification**: Run `make book` and `make book.html` after implementation

---
**Status**: Pending user approval
