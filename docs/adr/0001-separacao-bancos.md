# ADR 0001: Separar dados relacionais e séries temporais no AutoFlow Monitor

## Status

Proposto para avaliação da equipe.
Data: 03/11/2026.
Escopo: arquitetura acadêmica do AutoFlow Monitor, Grupo 3.

## Contexto

A AutoFlow fabrica carcaças de alumínio para bombas d'água automotivas. O piloto acompanha uma CNC e uma bancada de estanqueidade. A plataforma precisa relacionar peças, lotes, ciclos e testes, acompanhar a condição da máquina e identificar falhas do monitoramento.

Há dois perfis de dados. Cadastros, políticas, resultados de testes e alertas têm relações de negócio, autoria, estados e requisitos de integridade. Temperatura, RMS e pico de vibração formam observações ordenadas no tempo, com consultas por ativo, sensor e intervalo.

A bancada didática transmite indicadores por janela em lotes; a frequência de aquisição do sensor não é a frequência de gravação de amostras brutas no servidor. Não há ensaio de carga que demonstre insuficiência do PostgreSQL para o piloto.

## Alternativas consideradas

| Alternativa | Benefício | Limitação |
| --- | --- | --- |
| Somente PostgreSQL | Simplifica implantação, transações, backup e operação; também pode armazenar telemetria. | Exige projetar no mesmo armazenamento as consultas e o ciclo de vida dos dados de negócio e das séries. |
| Somente InfluxDB | Concentra observações temporais e simplifica o armazenamento dessas séries. | O modelo de cadastros, vínculos, aprovações e estados continuaria exigindo tratamento explícito de integridade na aplicação. |
| PostgreSQL e InfluxDB separados | Permite tratar os dois perfis de dados e exercitar fronteiras de persistência distintas. | Acrescenta operação, dois adaptadores e consistência entre armazenamentos. |

## Decisão proposta

Adotar PostgreSQL para os dados relacionais e InfluxDB para séries temporais.

| Armazenamento | Conteúdo |
| --- | --- |
| PostgreSQL | Ativos, sensores, pontos de medição, usuários e perfis, peças, lotes, ciclos, testes e retestes, políticas, estado das regras, checkpoints de ingestão, alertas, intervenções e pendências de notificação. |
| InfluxDB | Temperatura, RMS e pico por janela, sinais de vida, horário de coleta, unidade, qualidade e referências de ativo, sensor e contexto. |

O acesso passa por OperationalRepositories e TelemetryRepository. As regras de detecção utilizam esses contratos; apenas os adaptadores conhecem comandos SQL e detalhes da API InfluxDB.

Os identificadores de ativo, sensor, ciclo e janela relacionam os registros entre bancos. Esses vínculos são validados pela aplicação, sem pressupor chaves estrangeiras entre PostgreSQL e InfluxDB. Ausência de identificação confiável mantém o vínculo pendente.

A escolha distingue modelos e responsabilidades de armazenamento. A disponibilidade de linguagem SQL para consultas não transforma, por si só, uma base de séries temporais no cadastro relacional do domínio.

## Justificativa

O PostgreSQL oferece restrições de integridade, como chaves primárias, unicidade e chaves estrangeiras, úteis para representar os vínculos do processo. O InfluxDB representa observações com instante, valores e metadados, compatíveis com as séries dos sensores e as consultas por intervalo.

A separação permite definir estratégias próprias de retenção e consulta para telemetria e evidências de negócio. Sua adoção no exercício também atende à proposta de comparar persistência relacional e temporal.

A decisão não se baseia em uma alegação de desempenho já comprovada. Para o pequeno piloto, um único PostgreSQL é uma alternativa válida e mais simples. O custo da separação deve ser reavaliado com medições e capacidade operacional da equipe.

## Consequências positivas

- Responsabilidades e adaptações de persistência ficam explícitas.
- O domínio de produção mantém vínculos e estados no banco relacional.
- As consultas de janelas e tendências passam por um contrato próprio.
- Regras podem ser verificadas com repositórios substitutos em testes.
- Retenção de telemetria e preservação das evidências de alertas podem evoluir separadamente.

## Consequências negativas e riscos

- Serão necessários dois bancos, credenciais, monitoramento e procedimentos de backup.
- Não há uma transação única que confirme gravações nos dois bancos.
- Pode haver atraso entre a leitura persistida e a atualização do estado de negócio.
- Consultas combinadas exigem coordenação na aplicação.
- Reprocessar janelas pode duplicar contagens e alertas se a idempotência estiver incompleta.

## Mitigações e governança

- Preservar evento_id, janela_id, sequência, horário de coleta e horário de recebimento.
- Registrar checkpoints por lote. Um lote parcialmente processado permanece elegível a reprocessamento.
- Garantir que a mesma janela seja armazenada e avaliada de forma idempotente.
- Persistir alerta e pendência de envio na mesma transação PostgreSQL; entregar notificações depois e repetir falhas com o mesmo identificador.
- Tratar separadamente indisponibilidade do gateway, falta de atualização do sensor e falha do próprio armazenamento.
- Validar a persistência, a confirmação e a recuperação de mensagens na configuração escolhida do broker.
- Proibir SQL e acesso direto à API InfluxDB nos componentes de entrada e de domínio.
- Reavaliar a decisão caso a equipe não consiga operar a solução ou as medições indiquem que o custo supera o benefício.

## Critérios de validação pendentes

1. Reenviar o mesmo lote sem duplicar janelas, contagens de persistência, alertas ou notificações.
2. Interromper cada armazenamento e recuperar o processamento sem descartar silenciosamente lotes.
3. Reiniciar o ingestor entre gravar telemetria e avaliar regras; retomar usando os checkpoints.
4. Detectar ausência de comunicação mesmo sem novos eventos.
5. Rastrear uma leitura até ativo, sensor e contexto; manter vínculos desconhecidos pendentes.
6. Consultar o intervalo esperado do piloto e medir latência, volume e uso de recursos.
7. Demonstrar backup e restauração dos dois bancos e conferência dos vínculos.
8. Falhar a notificação e comprovar que o alerta e a pendência continuam disponíveis.

Os itens acima são critérios planejados, não resultados de ensaios realizados.

## Referências

- PostgreSQL: [Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html).
- InfluxData: [Write data to InfluxDB 3 Core](https://docs.influxdata.com/influxdb3/core/write-data/).
- C4 Model: [Component diagram](https://c4model.com/diagrams/component).
