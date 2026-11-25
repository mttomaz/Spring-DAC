workspace "AutoFlow Monitor - Grupo 3" "Monitoramento de condicao da CNC e da bancada de estanqueidade. Modelo C4 alinhado ao L2 e ao L3 da Sprint 3." {

    !identifiers flat
    !impliedRelationships false

    model {
        operador = person "Operador" "Acompanha a condicao da maquina no turno"
        tecnico = person "Tecnico de manutencao" "Valida alertas e conduz intervencoes"
        gestor = person "Gestor" "Consulta indicadores e criticidade"
        qualidade = person "Analista da qualidade" "Consulta resultados da bancada de estanqueidade"

        gateway = softwareSystem "Gateway industrial" "Aquisicao da CNC, dos sensores e da bancada; calcula indicadores por janela" "External"
        cmms = softwareSystem "CMMS/ERP" "Registra ordens e intervencoes de manutencao" "External"
        teams = softwareSystem "Microsoft Teams" "Canal de aviso a equipe" "External"
        email = softwareSystem "Servico de e-mail" "Canal de aviso a equipe" "External"

        autoflow = softwareSystem "AutoFlow Monitor" "Transforma telemetria em condicao, alertas e pendencias de notificacao" {
            mqtt = container "Broker MQTT" "Recebe lotes do gateway e retem mensagens ate a confirmacao do ingestor" "MQTT / TLS" "Queue"

            ingestor = container "Ingestor de Telemetria" "Valida lotes, avalia thresholds, registra alertas e retoma pendencias de envio" "Python - mesmo processo" {
                consumer = component "StreamConsumer" "Valida origem e payload; preserva horario, sequencia e qualidade" "Python / cliente MQTT"
                analyzer = component "ThresholdAnalyzer" "Aplica limites, persistencia, recuperacao e saude do monitoramento" "Python / servico de dominio"
                publisher = component "AlertPublisher" "Registra ocorrencias e pendencias antes de solicitar notificacoes" "Python / servico de aplicacao"
                scheduler = component "MonitoringScheduler" "Dispara verificacoes e reenvios periodicos" "Python / rotina periodica"
                temporalRepo = component "TelemetryRepository" "Grava e consulta leituras, janelas e qualidade" "Python / adaptador InfluxDB"
                relationalRepo = component "OperationalRepositories" "Isola contexto, politicas, estado, checkpoints, alertas e pendencias" "Python / repositories PostgreSQL"
            }

            influx = container "Banco de series temporais" "Temperatura, RMS, pico, sinal de vida e qualidade por instante" "InfluxDB" "Database"
            postgres = container "Banco relacional" "Ativos, sensores, producao, politicas, checkpoints, alertas, pendencias e intervencoes" "PostgreSQL" "Database"
            notifications = container "Servico de Notificacoes" "Integra Teams e e-mail, aplica retentativa e escalonamento" "Python / API HTTPS"
            api = container "API de Consulta" "Expoe estado, historico, alertas e resultados somente para leitura" "Python / API HTTPS"
            dashboard = container "Dashboard" "Exibe estado dos ativos, tendencias, historico e ocorrencias" "Aplicacao web"
        }

        # Contexto (C4 L1)
        gateway -> autoflow "Publica lotes de telemetria"
        operador -> autoflow "Acompanha condicao operacional"
        tecnico -> autoflow "Valida alertas e registra manutencao"
        gestor -> autoflow "Consulta indicadores"
        qualidade -> autoflow "Consulta resultados de ensaios"
        autoflow -> cmms "Sincroniza intervencoes"
        autoflow -> teams "Envia avisos"
        autoflow -> email "Envia avisos"

        # Conteineres (C4 L2)
        gateway -> mqtt "Publica lotes de telemetria" "MQTT / TLS"
        mqtt -> ingestor "Entrega lotes de telemetria" "MQTT / TLS"
        ingestor -> influx "Le e grava series" "HTTPS / API InfluxDB"
        ingestor -> postgres "Le e grava registros, checkpoints, alertas e pendencias" "SQL / TLS"
        ingestor -> notifications "Solicita envio e reenvio" "HTTPS / JSON"
        notifications -> teams "Envia aviso" "HTTPS"
        notifications -> email "Envia aviso" "HTTPS / SMTP"

        operador -> dashboard "Consulta estado das maquinas" "HTTPS"
        tecnico -> dashboard "Valida ocorrencias e intervencoes" "HTTPS"
        gestor -> dashboard "Consulta indicadores" "HTTPS"
        qualidade -> dashboard "Consulta resultados da bancada" "HTTPS"
        dashboard -> api "Consulta dados e valida ocorrencias" "HTTPS / JSON"
        api -> influx "Le series e tendencias" "HTTPS / API InfluxDB"
        api -> postgres "Le estado e historico, registra validacao" "SQL / TLS"
        api -> cmms "Sincroniza intervencao validada" "HTTPS / JSON"

        # Componentes do Ingestor (C4 L3)
        mqtt -> consumer "Entrega lotes de telemetria" "MQTT / TLS"
        consumer -> relationalRepo "Origem, contexto e checkpoints" "Chamada local"
        consumer -> temporalRepo "Grava leituras e qualidade" "Chamada local"
        consumer -> analyzer "Submete janelas validas" "Chamada local"
        scheduler -> analyzer "Dispara verificacao periodica" "Chamada local"
        scheduler -> publisher "Retoma pendencias de envio" "Chamada local"
        analyzer -> temporalRepo "Consulta janelas e ultimas leituras" "Chamada local"
        analyzer -> relationalRepo "Politicas, contexto e estado" "Chamada local"
        analyzer -> publisher "Solicita abertura ou atualizacao" "Chamada local"
        publisher -> relationalRepo "Persiste alerta e pendencia de envio" "Chamada local"
        publisher -> notifications "Solicita envio e reenvio" "HTTPS / JSON"
        temporalRepo -> influx "Le e grava series" "HTTPS / API InfluxDB"
        relationalRepo -> postgres "Le e grava registros" "SQL / TLS"
    }

    views {
        systemContext autoflow "ContextoAutoFlow" {
            include *
            autoLayout lr
        }

        container autoflow "ConteineresAutoFlow" {
            include *
            autoLayout lr
        }

        component ingestor "ComponentesIngestor" {
            include *
            autoLayout lr
        }

        dynamic autoflow "FluxoAlerta" "Cenario: anomalia persistente na CNC, alerta e notificacao" {
            gateway -> mqtt "Publica lote de telemetria"
            mqtt -> ingestor "Entrega o lote"
            ingestor -> influx "Grava janelas"
            ingestor -> postgres "Registra alerta e pendencia na mesma transacao"
            ingestor -> notifications "Solicita envio"
            notifications -> teams "Avisa a equipe"
            tecnico -> dashboard "Consulta e valida a ocorrencia"
            dashboard -> api "Consulta alerta e historico"
            api -> cmms "Sincroniza intervencao validada"
            autoLayout lr
        }

        styles {
            element "External" {
                background #999999
                color #ffffff
            }
            element "Person" {
                shape Person
            }
            element "Database" {
                shape Cylinder
            }
            element "Queue" {
                shape Pipe
            }
        }
    }
}
