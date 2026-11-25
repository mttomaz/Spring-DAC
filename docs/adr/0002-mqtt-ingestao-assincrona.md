# ADR 0002: Adotar MQTT com TLS e QoS 1 como canal assíncrono de ingestão de telemetria

## Status

Aceito.
Data: 17/11/2026.
Escopo: arquitetura acadêmica do AutoFlow Monitor, Grupo 3. A aceitação vale para o modelo de arquitetura; não comprova implementação, integração ou desempenho.

## Contexto

O gateway industrial envia à plataforma lotes com indicadores por janela (temperatura, RMS e pico de vibração, sinal de vida, qualidade), identificadores, sequência e horários de coleta. O Ingestor de Telemetria recebe esses lotes, grava as séries no InfluxDB, avalia thresholds e registra alertas no PostgreSQL ([ADR 0001](0001-separacao-bancos.md)).

Dois requisitos orientam a escolha. Primeiro, o ingestor e os bancos podem ficar lentos ou indisponíveis, e um lote não pode ser descartado em silêncio nem derrubar o gateway. Segundo, o gateway e o ingestor precisam de acoplamento fraco: o gateway não deve conhecer o endereço, a versão nem o estado do ingestor.

O volume do piloto (uma CNC e uma bancada de estanqueidade, com envio por janela em lotes) é pequeno. Não há ensaio de carga que compare as alternativas.

## Alternativas consideradas

| Alternativa | Benefício | Limitação |
| --- | --- | --- |
| Gateway chama o ingestor por HTTPS | Mais simples, sem componente adicional. | Acoplamento síncrono: indisponibilidade do ingestor exige buffer e repetição no gateway. |
| MQTT com TLS e QoS 1 (escolhida) | Protocolo leve, comum em IoT industrial, com publicação/assinatura desacoplada e retenção de mensagens até a confirmação. | Exige operar um broker e tratar entrega ao menos uma vez (duplicatas possíveis). |
| RabbitMQ (AMQP) | Roteamento, filas duráveis e reentrega maduros. | Recursos de roteamento além da necessidade do piloto; gateways industriais costumam falar MQTT nativamente. |
| Apache Kafka | Retenção e reprocessamento de grandes volumes. | Operação e infraestrutura desproporcionais ao piloto. |

## Decisão

Adotar um Broker MQTT, com TLS e QoS 1, entre o Gateway industrial e o Ingestor de Telemetria. O gateway publica lotes no broker; o `StreamConsumer` os consome e confirma o lote somente depois que a telemetria foi persistida e o checkpoint registrado. Sem a confirmação, o broker reentrega o lote de forma assíncrona.

Como a entrega QoS 1 é ao menos uma vez, o processamento deve ser idempotente: a mesma janela, identificada por `evento_id` e `janela_id`, não pode duplicar gravações, contagens de persistência, alertas ou notificações. O broker é um contêiner distinto no C4 L2; o ingestor é o único consumidor previsto.

Esta decisão trata apenas da entrada de telemetria. O reenvio de notificações usa a pendência persistida no PostgreSQL e o `MonitoringScheduler`, descritos no C4 L3 e no diagrama de sequência de resiliência.

## Consequências positivas

- O gateway e o ingestor ficam desacoplados no tempo: uma lentidão do InfluxDB ou do PostgreSQL não bloqueia a publicação.
- A falha de gravação gera reentrega pelo broker, sem retentativa implementada no gateway.
- O ingestor pode reiniciar entre a gravação e a avaliação das regras e retomar pelos checkpoints.
- TLS protege o canal entre gateway, broker e ingestor.
- O contrato do lote (identificadores, sequência, horários) fica explícito e testável com um broker de teste.

## Consequências negativas e riscos (trade-offs)

- Passa a existir mais um componente para operar, monitorar e proteger (credenciais, certificados, backup da configuração). O broker é um ponto único de falha no piloto.
- A entrega ao menos uma vez produz duplicatas; a idempotência precisa estar completa, ou haverá alertas repetidos.
- A reentrega pode alterar a ordem dos lotes; a avaliação por janela precisa tolerar lacunas e ordem de coleta (RN03 do C4 L3).
- Uma mensagem inválida reentregue sem parar pode bloquear o consumo. É preciso definir limite de tentativas e destino para lotes não processáveis.
- Pode haver atraso entre a coleta e a avaliação dos limites enquanto o lote é reentregue.
- O comportamento de confirmação manual e de sessão persistente depende da configuração do broker e do cliente.

## Mitigações e governança

- Confirmar o lote ao broker somente após a persistência da telemetria e do checkpoint.
- Preservar `evento_id`, `janela_id`, sequência, horário de coleta e horário de recebimento.
- Definir limite de reentregas e tratamento de lotes que excedam o limite, sem descarte silencioso.
- Tratar separadamente a indisponibilidade do broker, a do gateway e a falta de atualização do sensor.
- Reavaliar a decisão se a equipe não conseguir operar o broker ou se as medições indicarem que o custo supera o benefício.

## Critérios de validação pendentes

1. Interromper o InfluxDB por mais de 3 segundos e comprovar a reentrega do lote e a ausência de duplicatas.
2. Reiniciar o ingestor com lote não confirmado e recuperar o processamento pelos checkpoints.
3. Reenviar o mesmo lote e verificar que janelas, alertas e notificações não se duplicam.
4. Interromper o broker e verificar o comportamento do gateway e a detecção de ausência de comunicação.
5. Validar a confirmação manual e a persistência de mensagens na configuração escolhida do broker.

Os itens acima são critérios planejados, não resultados de ensaios realizados.

## Referências

- MQTT: [especificação do OASIS](https://mqtt.org/mqtt-specification/).
- C4 Model: [Container diagram](https://c4model.com/diagrams/container).
- Documentos relacionados: [C4 L2](../architecture/c4-l2-containers.md), [C4 L3](../architecture/c4-l3-ingestor.md) e [sequências de resiliência](../architecture/autoflow-sequencia-resiliencia.md).
