# AutoFlow Monitor: checklist de consistência da Sprint 3 (Passo 4)

Verificação inicial feita em 17/11/2026 e atualizada em 24/11/2026 sobre os artefatos de `docs/architecture/` e `docs/adr/`. A renderização dos blocos Mermaid foi conferida com o Mermaid 11.4.0 em um navegador; isso não substitui a conferência final no GitHub e no Mermaid Live Editor depois do merge. Os modelos em Structurizr DSL, PlantUML e D2 não foram compilados nesta verificação e precisam ser renderizados com as respectivas ferramentas antes da entrega.

## Resultado

| Item | Situação | Evidência |
| --- | --- | --- |
| Consistência de nomes e métodos | Atendido | Tabelas abaixo e tabela de rastreabilidade em [classes-interfaces-di.md](classes-interfaces-di.md). |
| Sintaxe compilável (Mermaid) | Atendido | Blocos Mermaid analisados e renderizados sem erro. |
| Sintaxe compilável (Structurizr, PlantUML, D2) | Pendente | Renderizar com Structurizr CLI, PlantUML e D2 CLI. |
| Desacoplamento por interfaces | Atendido | [classes-interfaces-di.md](classes-interfaces-di.md) mostra interfaces, adaptadores e substitutos de teste. |
| Transições de estado e gatilhos | Atendido | Tabela de gatilhos em [../Mermaid.md](../Mermaid.md). |
| Rastreabilidade no Git | Atendido na estrutura | Cada artefato entra por feature branch e Pull Request. |

## Consistência de nomes entre diagramas

| Elemento | C4 L2 | C4 L3 | Sequências | Classes |
| --- | --- | --- | --- | --- |
| Broker MQTT | sim | sim | sim | — |
| Ingestor de Telemetria | sim | sim (fronteira) | sim (agrupa os componentes) | — |
| Banco de series temporais | sim | sim | sim | — |
| Banco relacional | sim | sim | sim | — |
| Servico de Notificacoes | sim | sim | sim | — |
| API de Consulta e Dashboard | sim | fora do zoom | — | — |
| Teams e serviço de e-mail | sim | citados no texto | sim | — |
| StreamConsumer, ThresholdAnalyzer, AlertPublisher, MonitoringScheduler | — | sim | sim | sim |
| TelemetryRepository, OperationalRepositories | — | sim | sim | sim (interfaces) |

Os métodos usados nas sequências (`consultar_contexto`, `carregar_politica`, `salvar_estado`, `salvar_checkpoint`, `registrar_alerta_e_pendencia`, `listar_pendencias_abertas`, `registrar_tentativa`, `concluir_pendencia`, `gravar_janelas`, `ultima_leitura`, `avaliar_janelas`, `verificar_comunicacao`, `registrar_ocorrencia`, `enviar_pendencias`, `executar_verificacao`, `executar_reenvios`, `solicitar_envio`) existem no diagrama de classes e na tabela de contratos do C4 L3.

## Divergências da primeira verificação e como foram tratadas

| Divergência | Tratamento | Onde |
| --- | --- | --- |
| Modelo Structurizr desatualizado (Motor de regras e Servico de alertas separados, banco único, Dashboard lendo o banco) | Reescrito conforme o L2 e o L3, com visão de componentes do Ingestor | [../StructurizrDSL.dsl](../StructurizrDSL.dsl) |
| Métodos `salvar_checkpoint`, `listar_pendencias_abertas`, `concluir_pendencia` e `solicitar_envio` fora da tabela do L3 | Acrescentados ao L3, junto com `registrar_tentativa` | [c4-l3-ingestor.md](c4-l3-ingestor.md) |
| Sequência de e-mail sem método para registrar a nova tentativa | Criado `registrar_tentativa(pendencia_id, canal)` na interface e usado na sequência | [classes-interfaces-di.md](classes-interfaces-di.md), [autoflow-sequencia-resiliencia.md](autoflow-sequencia-resiliencia.md) |
| API de Consulta sem ADR | Registrada na ADR 0003, ainda como Proposto | [../adr/0003-api-de-consulta.md](../adr/0003-api-de-consulta.md) |
| Status diferentes nas ADRs 0001 (Proposto) e 0002 (Aceito) | ADR 0001 passa a Aceito, com o mesmo alcance da 0002 | [../adr/](../adr/) |
| Link do README citando `D2.d2` quando o arquivo é `d2.d2` | Corrigido | [../README.md](../README.md) |

## Pendências para a entrega

1. **Parâmetros sem ensaio.** O timeout de 3 s, o limite de reentregas e a espera crescente seguem como valores propostos; a tabela de parâmetros está em [autoflow-sequencia-resiliencia.md](autoflow-sequencia-resiliencia.md).
2. **ADR 0003 em aberto.** Passa a Aceito quando o PR for aprovado.
3. **Renderização das ferramentas.** Compilar o Structurizr DSL, o PlantUML (raias e fork/join) e o D2.
4. **Links entre PRs.** Alguns links cruzam artefatos de PRs diferentes e só funcionam depois do merge de todos.

## Checklist de apresentação

- [x] Nomes dos contêineres e serviços do C4 L2 iguais aos das sequências.
- [x] Arquivos `.md` e `.mmd` analisados e renderizados no Mermaid sem erro.
- [x] Diagrama de classes com interfaces e injeção de dependência.
- [x] Arquivos em `/docs/architecture/` e `/docs/adr/`.
- [x] Template de PR em `.github/PULL_REQUEST_TEMPLATE.md`.
- [ ] Regra de proteção ativada na branch padrão do repositório (`master`).
- [ ] Todos os PRs aprovados e mesclados.
- [ ] Conferir a renderização na visualização do GitHub após o merge.
- [ ] Renderizar Structurizr DSL, PlantUML e D2 e marcar a compilação no template de cada PR.
