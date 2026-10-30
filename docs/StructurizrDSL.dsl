workspace "Monitoramento IoT - Grupo 3" "Manutencao preventiva em fabrica de autopecas" {
    model {
        operador = person "Operador" "Acompanha condicao da maquina no turno"
        tecnico = person "Tecnico de manutencao" "Valida alertas e conduz intervencoes"
        gestor = person "Gestor" "Analisa indicadores e criticidade"
        qualidade = person "Analista da qualidade" "Consulta dados da bancada de estanqueidade"

        edge = softwareSystem "Sensores e gateway IoT" "Coleta sinais da CNC e resultados da bancada" "External"
        cmms = softwareSystem "CMMS/ERP" "Registra ordens e intervencoes" "External"
        notificacoes = softwareSystem "Canal de notificacoes" "Entrega avisos a equipe" "External"

        plataforma = softwareSystem "Plataforma IoT de manutencao preventiva" "Transforma telemetria em condicao, risco e alertas" {
            ingestao = container "Servico de ingestao" "Recebe e valida telemetria industrial" "Aplicacao"
            regras = container "Motor de regras" "Avalia thresholds, persistencia e criticidade" "Servico"
            dados = container "Banco de dados" "Guarda leituras, historico, limites e ocorrencias" "Banco de dados"
            alertas = container "Servico de alertas" "Prioriza eventos e solicita notificacoes" "Servico"
            painel = container "Dashboard" "Exibe estado dos ativos, tendencias e historico" "Aplicacao web"
        }

        edge -> plataforma "Envia telemetria de maquinas e testes"
        operador -> plataforma "Acompanha condicao operacional"
        tecnico -> plataforma "Valida alertas e registra manutencao"
        gestor -> plataforma "Consulta indicadores"
        qualidade -> plataforma "Consulta resultados de ensaios"
        plataforma -> cmms "Sincroniza intervencoes"
        plataforma -> notificacoes "Solicita notificacoes"

        edge -> ingestao "Envia telemetria"
        ingestao -> dados "Grava leituras e validacoes"
        ingestao -> regras "Solicita avaliacao de condicao"
        regras -> dados "Consulta historico e salva condicao"
        regras -> alertas "Envia anomalias classificadas"
        alertas -> dados "Registra alertas e evidencias"
        alertas -> notificacoes "Envia aviso ao responsavel"
        operador -> painel "Consulta estado das maquinas"
        tecnico -> painel "Valida ocorrencias e intervencoes"
        gestor -> painel "Consulta KPIs"
        qualidade -> painel "Consulta resultados da bancada"
        painel -> dados "Le indicadores, historico e alertas"
        painel -> cmms "Sincroniza intervencao validada"
    }

    views {
        systemContext plataforma "ContextoIoT" {
            include *
            autoLayout lr
        }
        container plataforma "ContainersIoT" {
            include *
            autoLayout lr
        }
        dynamic plataforma "FluxoAlerta" {
            title "Cenario: anomalia persistente na CNC"
            edge -> ingestao "Envia leitura de temperatura e vibracao"
            ingestao -> dados "Registra leitura valida"
            ingestao -> regras "Solicita avaliacao por thresholds"
            regras -> dados "Consulta historico e guarda criticidade"
            regras -> alertas "Emite evento Atenção ou Critico"
            alertas -> dados "Salva alerta e evidencia"
            alertas -> notificacoes "Avisa equipe"
            tecnico -> painel "Consulta e valida a ocorrencia"
            painel -> dados "Consulta alerta e historico"
            painel -> cmms "Sincroniza intervencao validada"
            autoLayout lr
        }
    }
}
