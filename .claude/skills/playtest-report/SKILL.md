---
name: playtest-report
description: "Roteiro de teste com alunos (playtest) do Chamado Aberto, ou transforma anotações de uma sessão em achados organizados. Use '/playtest-report novo' ou '/playtest-report analisar caminho'."
argument-hint: "[novo|analisar caminho-das-anotacoes]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
---

# Relatório de playtest — Chamado Aberto

Adaptada da skill `playtest-report` do projeto Claude Code Game Studios
(MIT, © 2026 Donchitos) — ver `.claude/THIRD_PARTY.md`.

## Fase 1: Modo

- `novo` → gera a ficha em branco (abaixo) para o professor usar observando alunos.
  Termina na Fase 2A.
- `analisar [caminho]` → lê anotações soltas (texto, transcrição, respostas de
  formulário) e preenche a ficha com achados organizados.
- Sem argumento → pergunte qual dos dois.

## Fase 2A: Ficha em branco

Mostre esta ficha ao usuário (e, se ele pedir, salve em `docs/playtest/ficha.md`):

```markdown
# Ficha de playtest — Chamado Aberto

## Sessão
- **Data**:
- **Versão** (rodapé da página ou commit):
- **Aluno/grupo** (pode ser só um código):
- **Plataforma**: computador do laboratório / celular / tablet / em casa
- **Entrada**: teclado / mouse / toque
- **Modo**: Treino / Avaliação
- **Tempo jogado**:
- **Já tinha jogado antes?** sim / não

## Primeiros 5 minutos
- Entendeu o objetivo sem ajuda? sim / não / em parte
- Entendeu os controles (andar, atender, responder)? sim / não / em parte
- Precisou abrir "Como jogar"? sim / não
- Reação: interessado / confuso / entediado / frustrado / animado
- Observações:

## Durante o jogo
### O que funcionou bem
-
### Onde travou ou se frustrou (gravidade: alta / média / baixa)
-
### Onde ficou confuso (texto, botão, regra)
-
### Momentos de diversão ou "aprendi!"
-

## Conteúdo dos chamados
| Tipo de chamado | Entendeu o problema? | Errou por quê? (conteúdo / leitura / pressa / interface) |
|---|---|---|

## Bugs vistos
| # | O que aconteceu | Gravidade | Acontece de novo? |
|---|---|---|---|

## Números (do relatório do jogo, se houver)
- Nota: · Pontos: · Resolvidos: · Estourados: · Erros:
- Tipo de chamado com mais erros:

## Avaliação geral
- Jogaria de novo? sim / não / talvez
- Dificuldade: fácil demais / boa / difícil demais
- Prazo dos chamados: folgado / bom / apertado
- A nota pareceu justa para o aluno? sim / não — por quê?

## 3 prioridades desta sessão
1.
2.
3.
```

No modo `novo`, pare aqui: **CONCLUÍDO** — ficha em branco gerada.

## Fase 2B: Analisar anotações

Leia as anotações e preencha a ficha. Compare com o que o jogo pretende (README,
regras em `scripts/ticket_system.gd`, conteúdo em `scripts/helpdesk.gd`) e aponte
onde a observação contradiz a intenção. Defeito claro (travou, não respondeu, texto
cortado, erro de conta) vai em **Bugs vistos**, não em frustrações.

Separe também **erros de conteúdo** (o aluno não sabia o assunto — informação para a
aula) de **erros de jogo** (não entendeu a interface ou a regra — problema do jogo).
Essa separação é a parte mais útil para o professor.

## Fase 3: Encaminhamento

Agrupe os achados em:
- **Mudanças de design** (confusão, regra que não funciona) → sugerir o agente
  `game-designer`
- **Ajustes de números** (prazo, pontuação, nota) → sugerir `/balance-check`
- **Bugs** → sugerir o agente `qa-tester` para registrar e reproduzir
- **Acessibilidade** (texto pequeno, cor, toque) → sugerir `accessibility-specialist`
- **Para a aula** (lacunas de conteúdo dos alunos) → listar para o professor

## Fase 4: Salvar

Pergunte: "Posso salvar este relatório em `docs/playtest/playtest-[data]-[grupo].md`?"
Se sim, grave (criando a pasta se preciso). Não inclua nomes completos de alunos sem o
professor pedir — prefira códigos.
