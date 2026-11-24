# AutoFlow Monitor: Diagramas de sequência com cenários de falha

## Situação da proposta

Modelo acadêmico proposto em 17/11/2026 para o Grupo 3 (Passo 2 do laboratório agêntico). Os participantes usam os mesmos nomes do [C4 L2](c4-l2-containers.md) e do [C4 L3](c4-l3-ingestor.md); métodos como `consumir_lote`, `avaliar_janelas`, `registrar_alerta_e_pendencia` e `executar_reenvios` seguem os contratos conceituais do L3. Prazos e políticas de repetição são parâmetros propostos, ainda sem ensaio, e este documento não comprova desempenho ou implementação.

Fluxo principal: o gateway publica um lote, o ingestor o grava, avalia os limites, registra o alerta e solicita a notificação. Cada cenário abaixo injeta uma falha nesse fluxo; o cenário 3 mostra a detecção de ausência de dados, que não depende da chegada de lotes. A retentativa é assíncrona: no cenário 1 pela reentrega do broker MQTT (ver [ADR 0002](../adr/0002-mqtt-ingestao-assincrona.md)); no cenário 2 pela pendência persistida e pelo `MonitoringScheduler`.

## Cenário 1: banco de séries temporais demora mais de 3 segundos

Fonte: [autoflow-sequencia-ingestao-timeout.mmd](autoflow-sequencia-ingestao-timeout.mmd).

```mermaid
sequenceDiagram
    title Ingestao de lote com banco lento (timeout de 3 s) e reentrega pelo broker

    participant mqtt as Broker MQTT
    box Ingestor de Telemetria
        participant consumer as StreamConsumer
        participant temporalRepo as TelemetryRepository
        participant analyzer as ThresholdAnalyzer
        participant relationalRepo as OperationalRepositories
    end
    participant influx as Banco de series temporais
    participant postgres as Banco relacional

    mqtt->>consumer: consumir_lote(lote) via MQTT QoS 1
    consumer->>relationalRepo: consultar_contexto(lote) e salvar_checkpoint(lote_id, "recebido")
    relationalRepo->>postgres: SQL / TLS
    postgres-->>relationalRepo: contexto e checkpoint gravados
    consumer->>temporalRepo: gravar_janelas(janelas validas)
    temporalRepo->>influx: grava series (timeout 3 s)

    alt InfluxDB responde em ate 3 s
        influx-->>temporalRepo: gravacao confirmada
        temporalRepo-->>consumer: janelas persistidas
        consumer->>relationalRepo: salvar_checkpoint(lote_id, "telemetria persistida")
        consumer->>analyzer: avaliar_janelas(contexto, janelas)
        analyzer->>relationalRepo: carregar_politica() e salvar_estado()
        consumer-->>mqtt: confirma lote (ACK)
    else InfluxDB demora mais de 3 s
        temporalRepo--xinflux: timeout de 3 s, cancela a chamada
        temporalRepo-->>consumer: TelemetryTimeout
        consumer->>relationalRepo: salvar_checkpoint(lote_id, "falha de armazenamento")
        Note over consumer,mqtt: Lote NAO confirmado ao broker e sem etapa "telemetria persistida"
        mqtt--)consumer: reentrega assincrona do lote (QoS 1, intervalo crescente)
        consumer->>temporalRepo: gravar_janelas(mesmo lote, mesmos evento_id e janela_id)
        alt janela ja gravada ou gravacao conclui na nova tentativa
            temporalRepo-->>consumer: janelas persistidas sem duplicar
            consumer->>analyzer: avaliar_janelas(contexto, janelas)
            consumer-->>mqtt: confirma lote (ACK)
        else tentativas esgotadas pela politica
            consumer->>relationalRepo: salvar_checkpoint(lote_id, "elegivel a reprocessamento")
            Note over consumer,postgres: Falha do armazenamento e tratada como falha de monitoramento, nunca como condicao normal
        end
    end
```

Pontos de resiliência: o lote só é confirmado ao broker depois da gravação; o checkpoint permanece em "recebido" após a falha; a reentrega usa os mesmos `evento_id` e `janela_id`, portanto não duplica janelas nem alertas; esgotadas as tentativas, o lote fica elegível a reprocessamento e a falha é tratada como falha de monitoramento, não como condição normal.

## Cenário 2: serviço de e-mail indisponível

Fonte: [autoflow-sequencia-notificacao-falha.mmd](autoflow-sequencia-notificacao-falha.mmd).

```mermaid
sequenceDiagram
    title Alerta com servico de e-mail indisponivel e reenvio assincrono de pendencias

    box Ingestor de Telemetria
        participant analyzer as ThresholdAnalyzer
        participant publisher as AlertPublisher
        participant scheduler as MonitoringScheduler
        participant relationalRepo as OperationalRepositories
    end
    participant postgres as Banco relacional
    participant notifications as Servico de Notificacoes
    participant teams as Microsoft Teams
    participant email as Servico de e-mail

    analyzer->>publisher: registrar_ocorrencia(condicao)
    publisher->>relationalRepo: registrar_alerta_e_pendencia(alerta)
    relationalRepo->>postgres: transacao unica grava alerta e pendencia de envio
    postgres-->>relationalRepo: commit
    relationalRepo-->>publisher: alerta_id e pendencia registrados

    publisher->>notifications: solicitar_envio(alerta_id, canais) via HTTPS / JSON, timeout curto
    notifications->>teams: envia aviso
    teams-->>notifications: entregue
    notifications->>email: envia aviso

    alt e-mail entrega o aviso
        email-->>notifications: aceito
        notifications-->>publisher: todos os canais entregues
        publisher->>relationalRepo: concluir_pendencia(pendencia_id)
    else servico de e-mail indisponivel
        email--xnotifications: erro ou timeout
        notifications-->>publisher: entrega parcial (Teams ok, e-mail pendente)
        publisher->>relationalRepo: registrar_tentativa(pendencia_id, "email"): pendencia do canal e-mail mantida
        Note over publisher,postgres: O alerta e a pendencia continuam gravados e visiveis no dashboard

        loop executar_reenvios() do MonitoringScheduler a cada intervalo, com espera crescente
            scheduler->>publisher: enviar_pendencias()
            publisher->>relationalRepo: listar_pendencias_abertas()
            publisher->>notifications: solicitar_envio(alerta_id, canais pendentes) com o mesmo alerta_id
            alt e-mail recuperado
                notifications->>email: envia aviso
                email-->>notifications: aceito
                notifications-->>publisher: entregue
                publisher->>relationalRepo: concluir_pendencia(pendencia_id)
            else ainda indisponivel
                notifications-->>publisher: falha mantida
                publisher->>relationalRepo: registrar_tentativa(pendencia_id, "email"): pendencia mantida
                Note over notifications: Escalonamento da pendencia conforme politica do Servico de Notificacoes
            end
        end
    end
```

Pontos de resiliência: alerta e pendência são gravados na mesma transação PostgreSQL antes de qualquer chamada externa; a queda do e-mail não impede o aviso por Teams nem a consulta do alerta no dashboard; o reenvio reutiliza `alerta_id` como chave de idempotência, evitando avisos duplicados; o escalonamento da pendência é responsabilidade do Serviço de Notificações, conforme o C4 L3.

## Cenário 3: ausência de dados sem novos lotes no broker

Fonte: [autoflow-sequencia-ausencia-dados.mmd](autoflow-sequencia-ausencia-dados.mmd).

```mermaid
sequenceDiagram
    title Deteccao de ausencia de dados pelo MonitoringScheduler (sem novos lotes no broker)

    box Ingestor de Telemetria
        participant scheduler as MonitoringScheduler
        participant analyzer as ThresholdAnalyzer
        participant temporalRepo as TelemetryRepository
        participant relationalRepo as OperationalRepositories
        participant publisher as AlertPublisher
    end
    participant influx as Banco de series temporais
    participant postgres as Banco relacional

    scheduler->>analyzer: executar_verificacao(agora) e verificar_comunicacao(agora)
    analyzer->>relationalRepo: carregar_politica(contexto) com o prazo maximo sem leitura
    relationalRepo->>postgres: SQL / TLS
    postgres-->>relationalRepo: politica
    analyzer->>temporalRepo: ultima_leitura(sensor_id)
    temporalRepo->>influx: consulta a ultima leitura (timeout 3 s)

    alt leitura recente dentro do prazo da politica
        influx-->>temporalRepo: leitura e horario de coleta
        temporalRepo-->>analyzer: ultima leitura valida
        analyzer->>relationalRepo: salvar_estado(estado) sem alteracao
    else sem leitura alem do prazo da politica
        influx-->>temporalRepo: leitura antiga ou ausente
        temporalRepo-->>analyzer: ultima leitura fora do prazo
        analyzer->>publisher: registrar_ocorrencia(falha de monitoramento: sem dados)
        publisher->>relationalRepo: registrar_alerta_e_pendencia(alerta)
        relationalRepo->>postgres: transacao unica grava alerta e pendencia de envio
        Note over analyzer,publisher: Ausencia de dados nao e tratada como condicao normal nem como maquina indisponivel
    else InfluxDB demora mais de 3 s
        temporalRepo--xinflux: timeout de 3 s, cancela a chamada
        temporalRepo-->>analyzer: TelemetryTimeout
        analyzer->>relationalRepo: salvar_estado(estado indeterminado)
        Note over scheduler,analyzer: A verificacao e repetida no proximo ciclo do scheduler
    end
```

Pontos de resiliência: a detecção não depende da chegada de lotes, porque quem dispara a verificação é o `MonitoringScheduler`; a falta de leitura dentro do prazo da política vira falha de monitoramento, nunca condição normal e nunca máquina indisponível (a falha de sensor tem alerta próprio, conforme a máquina de estados); a consulta ao InfluxDB também tem timeout de 3 s e, se estourar, o estado fica indeterminado e a verificação se repete no próximo ciclo.

## Parâmetros propostos (a validar)

Os valores abaixo são propostas para o piloto, sem ensaio. Só o timeout de 3 s vem do enunciado dos cenários; os demais são pontos de partida a confirmar ou ajustar na revisão e devem ser medidos nos critérios de validação da [ADR 0002](../adr/0002-mqtt-ingestao-assincrona.md).

| Parâmetro | Valor proposto | Onde aparece | Justificativa e risco |
| --- | --- | --- | --- |
| Timeout de gravação e consulta no InfluxDB | 3 s | Cenários 1 e 3 | Mantém o consumo do lote responsivo; um valor curto demais gera reentregas desnecessárias. |
| Entrega do lote pelo broker | MQTT QoS 1, ao menos uma vez | Cenário 1 | Garante a reentrega, mas admite duplicata; por isso `evento_id` e `janela_id` são idempotentes. |
| Limite de reentregas por lote | 5 tentativas (a confirmar) | Cenário 1 | Evita reentrega infinita de lote inválido; passado o limite o lote fica elegível a reprocessamento, sem descarte silencioso. |
| Espera entre reentregas | Crescente, 5 s dobrando até 5 min (a confirmar) | Cenário 1 | Dá tempo ao banco de se recuperar sem reentregar em rajada. |
| Timeout da chamada ao Serviço de Notificações | Curto, 5 s (a confirmar) | Cenário 2 | A chamada nunca fica no caminho de confirmação do lote (auditoria do [C4 L2](c4-l2-containers.md)). |
| Intervalo de `executar_reenvios()` | 60 s com espera crescente por pendência (a confirmar) | Cenário 2 | Repete pendências sem sobrecarregar um canal que ainda está fora. |
| Intervalo de `executar_verificacao(agora)` | Menor que o prazo de detecção da política | Cenário 3 | O L3 exige que o intervalo cumpra o prazo de detecção configurado. |

## Mensagens e métodos usados

Todo método chamado nos diagramas existe nas interfaces do [diagrama de classes](classes-interfaces-di.md): `consumir_lote`, `consultar_contexto`, `salvar_checkpoint`, `gravar_janelas`, `avaliar_janelas`, `carregar_politica`, `salvar_estado`, `registrar_ocorrencia`, `registrar_alerta_e_pendencia`, `solicitar_envio`, `listar_pendencias_abertas`, `registrar_tentativa`, `concluir_pendencia`, `enviar_pendencias`, `executar_verificacao`, `executar_reenvios`, `verificar_comunicacao` e `ultima_leitura`.

## Referências

- Mermaid: [Sequence diagrams](https://mermaid.js.org/syntax/sequenceDiagram.html).
- ADR 0001: [separação dos bancos](../adr/0001-separacao-bancos.md).
