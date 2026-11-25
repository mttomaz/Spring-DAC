# ADR 0003: Introduzir uma API de Consulta entre o Dashboard e os bancos

## Status

Proposto para avaliação da equipe; passa a Aceito se este PR for aprovado.
Data: 24/11/2026.
Escopo: arquitetura acadêmica do AutoFlow Monitor, Grupo 3. A decisão vale para o modelo; não comprova implementação, integração ou desempenho.

## Contexto

O modelo Structurizr da sprint anterior fazia o Dashboard ler diretamente o banco de dados e sincronizar intervenções com o CMMS/ERP. Depois da [ADR 0001](0001-separacao-bancos.md), há dois bancos: PostgreSQL (estado, alertas, pendências, intervenções) e InfluxDB (séries temporais). A auditoria de acoplamento do [C4 L2](../architecture/c4-l2-containers.md) apontou que o Dashboard, se lesse os dois bancos, ficaria acoplado aos dois esquemas e disputaria recursos com o Ingestor de Telemetria.

O [C4 L3](../architecture/c4-l3-ingestor.md) já deixa Dashboard e API de Consulta fora do zoom do ingestor. Esta ADR registra a decisão de incluir a API de Consulta no L2, que antes não constava em nenhuma ADR.

## Alternativas consideradas

| Alternativa | Benefício | Limitação |
| --- | --- | --- |
| Dashboard lê os dois bancos diretamente | Menos um contêiner para operar. | Acopla a interface aos esquemas de PostgreSQL e InfluxDB e dispersa credenciais e a integração com o CMMS/ERP. |
| Ingestor expõe os endpoints de consulta | Reaproveita repositórios e processo existentes. | Mistura leitura com o caminho de ingestão; uma consulta pesada compete com o consumo de lotes. |
| API de Consulta separada (escolhida) | Isola o Dashboard dos esquemas, concentra leitura e integração com o CMMS/ERP e permite escalar ou proteger a leitura à parte. | Acrescenta um contêiner e mais uma API a manter, monitorar e proteger. |

## Decisão proposta

Criar o contêiner **API de Consulta** (Python / API HTTPS) entre o Dashboard e os bancos. O Dashboard fala somente com a API. A API acessa os bancos por repositórios próprios, em modo leitura, com uma exceção: registrar a validação de ocorrência feita pelo técnico. A API é o único ponto de integração com o CMMS/ERP, onde sincroniza a intervenção validada.

O Ingestor de Telemetria continua sem conhecer o Dashboard nem a API de Consulta.

## Justificativa

A separação mantém o Dashboard dependente de um contrato HTTP, e não de SQL ou da API do InfluxDB, o mesmo princípio de desacoplamento por interfaces da [ADR 0001](0001-separacao-bancos.md). Concentrar a integração com o CMMS/ERP em um ponto evita credenciais espalhadas e sincronizações duplicadas.

## Consequências positivas

- O Dashboard não depende dos esquemas dos bancos.
- Consultas combinadas (estado no PostgreSQL e tendência no InfluxDB) ficam em um só lugar.
- A leitura não disputa o mesmo processo do ingestor.
- A integração com o CMMS/ERP fica em um único contêiner.

## Consequências negativas e riscos (trade-offs)

- Mais um contêiner e uma API para operar, versionar e proteger (autenticação e autorização por perfil).
- A API de Consulta e o Ingestor acessam o PostgreSQL ao mesmo tempo; uma consulta pesada ainda pode competir por recursos do banco.
- O registro de validação de ocorrência é uma escrita; sem cuidado, a API deixa de ser somente leitura e pode conflitar com o estado gravado pelo ingestor.
- A API é um ponto único de falha para o Dashboard e para a sincronização com o CMMS/ERP.

## Mitigações e governança

- Restringir a escrita da API ao registro de validação de ocorrência, por meio de um repositório com permissão própria.
- Autenticar e autorizar por perfil (operador, técnico, gestor, analista da qualidade).
- Tornar a sincronização com o CMMS/ERP idempotente, com identificador estável da intervenção.
- Reavaliar a decisão se a equipe não conseguir operar o contêiner adicional ou se as medições indicarem que o custo supera o benefício.

## Critérios de validação pendentes

1. Consultar estado, histórico e alertas pelo Dashboard sem nenhum acesso direto aos bancos.
2. Validar uma ocorrência e comprovar que o estado gravado pelo ingestor não é sobrescrito.
3. Repetir a sincronização de uma intervenção validada e comprovar que o CMMS/ERP não recebe duplicatas.
4. Derrubar a API e verificar que o Ingestor continua ingerindo e alertando.

Os itens acima são critérios planejados, não resultados de ensaios realizados.

## Referências

- C4 Model: [Container diagram](https://c4model.com/diagrams/container).
- Documentos relacionados: [C4 L2](../architecture/c4-l2-containers.md), [C4 L3](../architecture/c4-l3-ingestor.md), [ADR 0001](0001-separacao-bancos.md) e [ADR 0002](0002-mqtt-ingestao-assincrona.md).
