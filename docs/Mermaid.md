# Projeto IoT Industrial — Diagramas Mermaid

## 1. Fluxo de telemetria e verificação de thresholds

```mermaid
flowchart TD
    CNC["Sensores CNC: temperatura, vibracao e horas"] --> GW["Gateway IoT"]
    BAN["Bancada: pressao, ciclo e resultado"] --> GW
    GW --> ING["Receber telemetria"]
    ING --> VAL["Validar identificacao, horario e valores"]
    VAL --> OK{"Dados validos?"}
    OK -- Nao --> FALHA["Registrar falha de sensor ou comunicacao"]
    FALHA --> AVISO["Notificar equipe sobre falha de monitoramento"]
    AVISO --> DASH["Atualizar historico e dashboard"]
    OK -- Sim --> BD["Armazenar medicoes com rastreabilidade"]
    BD --> REGRAS["Consultar limites, persistencia e criticidade"]
    REGRAS --> LIMITE{"Threshold ultrapassado?"}
    LIMITE -- Nao --> NORMAL["Condicao normal"]
    NORMAL --> DASH
    LIMITE -- Sim --> CONF{"Desvio persistente ou combinacao critica?"}
    CONF -- Nao --> OBS["Registrar desvio isolado e observar tendencia"]
    OBS --> DASH
    CONF -- Sim --> RISCO{"Risco alto?"}
    RISCO -- Nao --> ATENCAO["Classificar: Atencao"]
    RISCO -- Sim --> CRITICO["Classificar: Critico"]
    ATENCAO --> ALERTA["Gerar alerta priorizado e guardar evidencia"]
    CRITICO --> ALERTA
    ALERTA --> NOTIF["Notificar operador e tecnico"]
    NOTIF --> ACAO["Validar alerta e planejar manutencao"]
    ACAO --> CMMS["Registrar ou sincronizar intervencao no CMMS/ERP"]
    CMMS --> DASH
```

## 2. Máquina de estados do equipamento

```mermaid
stateDiagram-v2
    direction LR
    state "Normal" as Normal
    state "Atencao" as Atencao
    state "Critico" as Critico
    state "Em manutencao" as Manutencao
    state "Indisponivel" as Indisponivel

    [*] --> Normal
    Normal --> Atencao: Desvio persistente
    Atencao --> Critico: Limite critico ou sinais combinados
    Atencao --> Normal: Leituras estabilizadas
    Critico --> Atencao: Risco reduzido e monitorado
    Normal --> Manutencao: Preventiva programada
    Atencao --> Manutencao: Intervencao planejada
    Critico --> Manutencao: Intervencao urgente
    Normal --> Indisponivel: Parada inesperada
    Critico --> Indisponivel: Falha ou parada
    Indisponivel --> Manutencao: Reparo iniciado
    Manutencao --> Normal: Testes aprovados e liberacao
    Manutencao --> Indisponivel: Falha nao solucionada

    note right of Indisponivel
        Indisponivel significa maquina parada.
        Falha de sensor gera alerta proprio,
        sem alterar automaticamente este estado.
    end note
```

## 3. Gatilhos das transições de estado

Cada transição da máquina de estados tem um gatilho no fluxo de atividades do item 1 (mesmo fluxo em [PlantUML.puml](PlantUML.puml) e [d2.d2](d2.d2)). Mapeamento proposto, sem ensaio:

| Transição | Gatilho | Atividade do fluxo que o dispara |
| --- | --- | --- |
| Normal → Atenção | Desvio persistente | "Desvio persistente ou combinação crítica?" = Sim e "Risco alto?" = Não, que leva a "Classificar: Atenção" |
| Atenção → Crítico | Limite crítico ou sinais combinados | "Risco alto?" = Sim, que leva a "Classificar: Crítico" |
| Atenção → Normal | Leituras estabilizadas | "Threshold ultrapassado?" = Não, que leva a "Condição normal" |
| Crítico → Atenção | Risco reduzido e monitorado | Reavaliação com "Risco alto?" = Não |
| Normal → Em manutenção | Preventiva programada | Ordem preventiva no CMMS/ERP, fora do fluxo de telemetria |
| Atenção → Em manutenção | Intervenção planejada | "Validar alerta e planejar manutenção", seguido de "Registrar ou sincronizar intervenção no CMMS/ERP" |
| Crítico → Em manutenção | Intervenção urgente | Mesmo fluxo, com alerta priorizado como Crítico |
| Normal → Indisponível | Parada inesperada | Parada informada pela operação ou pelo CMMS/ERP |
| Crítico → Indisponível | Falha ou parada | Parada informada pela operação ou pelo CMMS/ERP |
| Indisponível → Em manutenção | Reparo iniciado | "Registrar ou sincronizar intervenção no CMMS/ERP" |
| Em manutenção → Normal | Testes aprovados e liberação | Encerramento da intervenção no CMMS/ERP com leituras normais |
| Em manutenção → Indisponível | Falha não solucionada | Encerramento da intervenção sem liberação |

A atividade "Registrar falha de sensor ou comunicação" gera alerta próprio de monitoramento e **não** dispara nenhuma transição: a falha de sensor não prova que a máquina parou.
