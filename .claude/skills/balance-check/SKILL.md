---
name: balance-check
description: "Verifica o equilíbrio do Chamado Aberto: pontuação, nota de 0 a 10, prazos (SLA), ritmo de chamados, dificuldade dos minijogos e estratégias degeneradas. Use com 'confira o equilíbrio' ou '/balance-check [sistema]'."
argument-hint: "[pontuacao|nota|prazos|dificuldade|caminho-de-arquivo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Bash
---

# Verificação de equilíbrio — Chamado Aberto

Adaptada da skill `balance-check` do projeto Claude Code Game Studios
(MIT, © 2026 Donchitos) — ver `.claude/THIRD_PARTY.md`.

## Antes de tudo: dados insuficientes

**Se faltar o que esta verificação precisa ler, a resposta é "não deu para avaliar",
não um relatório preenchido.**

1. Liste as entradas lidas (arquivos de código, README, saídas de simulação).
2. Para cada uma, registre `ENCONTRADO` ou `AUSENTE`.
3. Seção sem dados ou sem alvo declarado = **`NÃO AVALIADO — SEM DADOS`**
   (diga o que faltou). Não estime, não deduza de outro arquivo.

Ausência de evidência não é evidência de ausência: uma busca sem resultados porque
não havia o que buscar não verificou nada.

## Fase 1: Domínio

Pelo argumento (o texto inteiro):
- **pontuacao** → pontos por chamado, rapidez, prioridade, penalidades, multiplicador
  de sequência (`TicketSystem.points_for`, `multiplier_after`)
- **nota** → fórmula da nota de 0 a 10 (40% resolução, 40% precisão, 20% agilidade)
- **prazos** → SLA por tipo/prioridade, intervalo entre chamados, duração do expediente
- **dificuldade** → número de opções e armadilhas por minijogo, progressão do Treino
- **caminho de arquivo** → leia o arquivo e deduza o domínio

Sem argumento: pergunte qual sistema.

## Fase 2: Ler os dados

- `scripts/ticket_system.gd` — tipos, prazos, pontos, nota, sorteio
- `scripts/helpdesk.gd` — conteúdo dos casos e quantidade de opções
- `scripts/tasks/*.gd` — regras de cada minijogo (o que conta como erro)
- `README.md` — tabela de pontuação publicada para os alunos (é o **alvo declarado**:
  se o código diverge do README, é um achado)

Anote todo arquivo lido.

## Fase 3: Alvos

Alvos vêm do README, de comentários no código e destes princípios do projeto:
- Penalidades leves: um erro não pode custar mais que uma fração pequena dos pontos de
  um chamado resolvido.
- A nota deve medir conhecimento: um aluno que acerta tudo devagar não pode tirar nota
  baixa; um aluno que chuta não pode tirar nota alta.
- Modo Avaliação: mesma sequência para o mesmo código de turma; dificuldade estável.

Valor sem alvo em lugar nenhum: liste em "Valores que precisam de atenção" como
`sem intervalo declarado — não julgado`.

## Fase 4: Análise

Quando útil, **simule** com um script GDScript temporário em headless (na pasta de
rascunho, não no repositório), por exemplo:
- jogador perfeito (rápido, sem erros), lento sem erros, rápido chutando, que ignora
  chamados difíceis, que erra 1 vez por chamado;
- nota e pontos de cada perfil num expediente de Avaliação.

Verifique:
- **Estratégias degeneradas**: chutar todas as opções compensa? Deixar chamados
  estourarem e só pegar os fáceis compensa? O multiplicador de sequência premia demais?
- **Proporções**: peso de rapidez vs. acerto; penalidade vs. ganho.
- **Prazos**: dá tempo de ler o caso e andar até a mesa? (Leitura lenta não deve
  derrubar a nota de quem sabe o conteúdo.)
- **Coerência**: README × código; texto da ajuda do menu × código.

## Fase 5: Relatório

```
## Verificação de equilíbrio: [sistema]

### Fontes de dados analisadas
- [arquivos lidos / simulações rodadas]

### Resumo: [NÃO AVALIADO / SAUDÁVEL / PREOCUPAÇÕES / PROBLEMAS CRÍTICOS]

### Valores fora do alvo
| Valor | Alvo | Atual | Problema |

### Estratégias degeneradas encontradas
- [estratégia e por que é um problema]

### Simulação de perfis (se rodada)
| Perfil | Pontos | Nota |

### Recomendações
| Prioridade | Problema | Ajuste sugerido | Impacto |

### Valores que precisam de atenção
```

Escolha o resumo pelo pior achado:
- **PROBLEMAS CRÍTICOS** — estratégia degenerada que domina, ou nota que não mede o
  que deveria
- **PREOCUPAÇÕES** — valores fora do alvo que um ajuste resolve
- **NÃO AVALIADO** — faltou dado ou alvo para alguma seção (diga qual)
- **SAUDÁVEL** — tudo comparado a um alvo, sem achados

## Fase 6: Próximo passo

Pergunte ao usuário: corrigir o problema de maior prioridade agora, salvar o relatório
em `docs/qa/equilibrio-[sistema]-[data].md` ou parar aqui.
Ao corrigir: atualize código, README e texto de ajuda juntos, ajuste os testes de
pontuação em `tests/test_game.gd` e rode todos os testes.
