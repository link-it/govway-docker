# Guida all'utilizzo di Tomcat CLI

## Panoramica

`tomcat-cli.sh` è uno strumento di gestione della configurazione per Apache Tomcat che permette di modificare i file XML di configurazione di Tomcat (`server.xml` e `context.xml`) utilizzando una sintassi semplice basata su direttive. Fornisce un'alternativa all'interfaccia CLI native di WildFly per i deployment di GovWay basati su Tomcat.

Lo strumento è disponibile in `/usr/local/bin/tomcat-cli.sh` all'interno dei container GovWay costruiti con Tomcat 9 o Tomcat 10.

## Come Funziona

Il tool CLI:
1. Legge le direttive da un file di input (formato `.cli`)
2. Analizza comandi basati su XPath con operazioni e parametri
3. Modifica i file di configurazione XML di Tomcat usando un parser Java
4. Valida la sintassi XML con `xmlstarlet`
5. Effettua automaticamente il rollback delle modifiche in caso di errori di validazione

### Componenti Interni

- **Wrapper shell**: `tomcat-cli.sh` (righe 1-34 in commons/tomcat9/tomcat-cli.sh)
- **CLI Java**: `TomcatConfigCli.java` (motore di manipolazione XML)
- **File target**: `$CATALINA_HOME/conf/server.xml` e `$CATALINA_HOME/conf/context.xml`

## Sintassi delle Direttive

Ogni direttiva segue questo formato:

```
<xpath>: <operazione> <parametri>
```

### Componenti

- **`<xpath>`**: Espressione XPath che identifica l'elemento target
  - I percorsi che iniziano con `/Context` modificano `context.xml`
  - Tutti gli altri percorsi modificano `server.xml`
- **`<operazione>`**: Azione da eseguire (vedi sezione Operazioni)
- **`<parametri>`**: Attributi o valori separati da virgole

### Continuazione su Più Righe

Le direttive lunghe possono estendersi su più righe usando il backslash (`\`):

```
/Server/Service/Connector:add port=8080, \
  protocol=HTTP/1.1, \
  connectionTimeout=20000
```

### Commenti

Le righe che iniziano con `#` sono trattate come commenti e ignorate:

```
# Configura il connettore HTTP
/Server/Service/Connector:add port=8080, protocol=HTTP/1.1
```

## Operazioni

### add / append

Aggiunge un nuovo elemento come ultimo figlio dell'elemento padre.

**Sintassi:**
```
<xpath-padre>/<nome-elemento>: add attributo1=valore1, attributo2=valore2, ...
```

**Esempio:**
```
/Server/Service/Connector:add port=9080, protocol=HTTP/1.1, connectionTimeout=20000
```

Questo crea:
```xml
<Service>
  <Connector port="9080" protocol="HTTP/1.1" connectionTimeout="20000" />
</Service>
```

### top

Aggiunge un nuovo elemento come primo figlio dell'elemento padre.

**Sintassi:**
```
<xpath-padre>/<nome-elemento>: top attributo1=valore1, attributo2=valore2, ...
```

**Esempio:**
```
/Server/Service/Engine/Host/Valve:top className=org.apache.catalina.valves.AccessLogValve
```

### delete

Rimuove un elemento dalla configurazione.

**Sintassi:**
```
<xpath>: delete
```

**Esempio:**
```
/Server/Service/Connector[@port='8080']:delete
```

### write-attribute

Imposta o aggiorna gli attributi su un elemento esistente.

**Sintassi:**
```
<xpath>: write-attribute attributo1=valore1, attributo2=valore2, ...
```

**Esempio:**
```
/Server/Service/Connector[@port='8080']:write-attribute maxThreads=200, minSpareThreads=25
```

### read-attribute

Legge e visualizza i valori degli attributi (solo output, non modifica la configurazione).

**Sintassi:**
```
<xpath>: read-attribute nomeAttributo
```

**Esempio:**
```
/Server/Service/Connector[@port='8080']:read-attribute maxThreads
```

Output:
```
maxThreads = 200
```

### delete-attribute

Rimuove attributi da un elemento.

**Sintassi:**
```
<xpath>: delete-attribute attributo1, attributo2, ...
```

**Esempio:**
```
/Server/Service/Connector[@port='8080']:delete-attribute redirectPort
```

## Espressioni XPath

Lo strumento utilizza la sintassi XPath standard per localizzare elementi nell'albero XML.

### Pattern Comuni

**Selezione per percorso elemento:**
```
/Server/Service/Engine/Host
```

**Selezione per valore di attributo:**
```
/Server/Service/Connector[@port='8080']
/Server/GlobalNamingResources/Resource[@name='myDataSource']
```

**Selezione di elementi nidificati:**
```
/Server/Service/Engine/Host/Valve
```

## Esempi Pratici

### Esempio 1: Aggiungere un Connettore HTTP

Creare un file `add_connector.cli`:

```
# Aggiungi nuovo connettore HTTP sulla porta 9080
/Server/Service/Connector:add port=9080, \
  protocol=HTTP/1.1, \
  connectionTimeout=20000, \
  redirectPort=8443, \
  maxThreads=150
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/add_connector.cli
```

### Esempio 2: Configurare un DataSource

Creare un file `datasource.cli`:

```
# Aggiungi risorsa JNDI globale
/Server/GlobalNamingResources/Resource:add \
  name=jdbc/MyDB, \
  auth=Container, \
  type=javax.sql.DataSource, \
  driverClassName=org.postgresql.Driver, \
  url=jdbc:postgresql://dbserver:5432/mydb, \
  username=dbuser, \
  password=dbpass, \
  maxTotal=20, \
  maxIdle=10, \
  maxWaitMillis=10000

# Collega al contesto
/Context/ResourceLink:add \
  name=jdbc/MyDB, \
  global=jdbc/MyDB, \
  type=javax.sql.DataSource
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/datasource.cli
```

### Esempio 3: Aggiungere una Rewrite Valve

Creare un file `rewrite.cli`:

```
# Aggiungi RewriteValve per il rewriting degli URL
/Server/Service/Engine/Host/Valve:add \
  className=org.apache.catalina.valves.rewrite.RewriteValve, \
  configuration=/etc/tomcat/rewrite.config
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/rewrite.cli
```

### Esempio 4: Configurare un Thread Pool Executor

Creare un file `executor.cli`:

```
# Aggiungi executor dedicato per connettore specifico
/Server/Executor:add \
  name=myWorkerPool, \
  namePrefix=myWorker-, \
  maxThreads=200, \
  minSpareThreads=50

# Aggiorna connettore per usare l'executor
/Server/Service/Connector[@port='8080']:write-attribute executor=myWorkerPool
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/executor.cli
```

### Esempio 5: Modificare un Connettore Esistente

Creare un file `tune_connector.cli`:

```
# Leggi il valore corrente di maxThreads
/Server/Service/Connector[@port='8080']:read-attribute maxThreads

# Aggiorna attributi del connettore
/Server/Service/Connector[@port='8080']:write-attribute \
  maxThreads=300, \
  acceptCount=100, \
  enableLookups=false, \
  compression=on
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/tune_connector.cli
```

### Esempio 6: Rimuovere Configurazioni Non Necessarie

Creare un file `cleanup.cli`:

```
# Rimuovi connettore AJP se non necessario
/Server/Service/Connector[@protocol='AJP/1.3']:delete

# Rimuovi AccessLogValve
/Server/Service/Engine/Host/Valve[@className='org.apache.catalina.valves.AccessLogValve']:delete
```

Eseguire:
```bash
/usr/local/bin/tomcat-cli.sh /path/to/cleanup.cli
```

## Utilizzo con le Immagini Docker GovWay

### Durante l'Inizializzazione del Container

Posizionare i file `.cli` nella directory `/docker-entrypoint-govway.d/`. Verranno eseguiti automaticamente durante l'avvio del container:

```bash
docker run -v /path/to/my-config.cli:/docker-entrypoint-govway.d/my-config.cli \
  linkitaly/govway:latest
```

Lo script di entrypoint (commons/tomcat9/entrypoint.sh:463) elabora automaticamente tutti i file `*.cli` trovati in questa directory.

### Esecuzione Manuale all'Interno del Container

```bash
# Entra nel container in esecuzione
docker exec -it govway-container bash

# Crea file CLI
cat > /tmp/my-changes.cli <<EOF
/Server/Service/Connector[@port='8080']:write-attribute maxThreads=500
EOF

# Applica le modifiche
/usr/local/bin/tomcat-cli.sh /tmp/my-changes.cli

# Riavvia Tomcat per applicare
catalina.sh stop
catalina.sh start
```

### Utilizzo di Variabili d'Ambiente

**Nota importante**: Il tool `tomcat-cli.sh` scrive le direttive nei file XML di Tomcat **in modo letterale**, senza espandere le variabili d'ambiente. Tuttavia, **Tomcat stesso** supporta la sintassi `${VARIABILE}` nei suoi file di configurazione XML e le espande automaticamente al momento dell'avvio del server.

**Come funziona:**

1. Il file `.cli` contiene direttive con variabili in formato `${VAR_NAME:-default}`
2. `tomcat-cli.sh` scrive letteralmente `${VAR_NAME:-default}` negli XML di Tomcat
3. Quando Tomcat si avvia, legge i file XML ed espande le variabili d'ambiente

**Esempio di file CLI con variabili:**

```bash
# File: custom-connector.cli
/Server/Service/Connector:add \
  port=${HTTP_PORT:-8080}, \
  maxThreads=${MAX_THREADS:-200}, \
  connectionTimeout=${CONN_TIMEOUT:-20000}
```

Quando esegui:
```bash
/usr/local/bin/tomcat-cli.sh custom-connector.cli
```

Il file `server.xml` conterrà letteralmente:
```xml
<Connector port="${HTTP_PORT:-8080}"
           maxThreads="${MAX_THREADS:-200}"
           connectionTimeout="${CONN_TIMEOUT:-20000}"/>
```

**All'avvio di Tomcat**, se le variabili sono definite:
```bash
export HTTP_PORT=9090
export MAX_THREADS=300
catalina.sh start
```

Tomcat espande automaticamente le variabili caricando la configurazione come:
```xml
<Connector port="9090"
           maxThreads="300"
           connectionTimeout="20000"/>
```

**In ambiente Docker:**

```bash
docker run -e HTTP_PORT=9090 \
  -e MAX_THREADS=300 \
  -v /path/to/custom-connector.cli:/docker-entrypoint-govway.d/custom-connector.cli \
  linkitaly/govway:latest
```

Le variabili vengono espanse automaticamente da Tomcat all'avvio del container.

## Esempi Reali di GovWay

### Configurazione Integration Manager

File: `integrationmanager.cli` (vedi root del progetto)

```
# Crea thread pool dedicato per Integration Manager
/Server/Executor:add name=http-im-worker, \
  namePrefix=http-im-worker-, \
  maxThreads=${WILDFLY_HTTPIM_WORKER-MAX-THREADS:-100}

# Aggiungi connettore HTTP per Integration Manager sulla porta 9080
/Server/Service/Connector:add port=9080, \
  protocol=HTTP/1.1, \
  connectionTimeout=20000, \
  redirectPort=8443, \
  executor=http-im-worker, \
  maxPostSize=${WILDFLY_MAX-POST-SIZE:25485760}

# Aggiungi datasource per runtime Integration Manager
/Server/GlobalNamingResources/Resource:add \
  name=org.govway.datasource.runtime.imV1, \
  auth=Container, \
  type=javax.sql.DataSource, \
  driverClassName=${GOVWAY_DS_DRIVER_CLASS}, \
  url=jdbc:postgresql://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}?${GOVWAY_DS_CONN_PARAM}, \
  username=${GOVWAY_DB_USER}, \
  password=${GOVWAY_DB_PASSWORD}, \
  maxTotal=${IM_MAX_POOL:-50}, \
  minIdle=0, \
  maxIdle=${IM_MIN_POOL:-2}

# Collega datasource al contesto
/Context/ResourceLink:add \
  name=org.govway.datasource.runtime.imV1, \
  global=org.govway.datasource.runtime.imV1, \
  type=javax.sql.DataSource
```

### Configurazione Consegna Asincrona

File: `consegnaAsincrona.cli` (vedi root del progetto)

```
# Aggiungi datasource per runtime consegna asincrona
/Server/GlobalNamingResources/Resource:add \
  name=org.govway.datasource.runtime.consegnaAsincrona, \
  auth=Container, \
  type=javax.sql.DataSource, \
  driverClassName=${GOVWAY_DS_DRIVER_CLASS}, \
  url=jdbc:postgresql://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}?${GOVWAY_DS_CONN_PARAM}, \
  username=${GOVWAY_DB_USER}, \
  password=${GOVWAY_DB_PASSWORD}, \
  maxTotal=${CONSEGNA_ASINCRONA_MAX_POOL:-50}, \
  minIdle=0

# Collega al contesto
/Context/ResourceLink:add \
  name=org.govway.datasource.runtime.consegnaAsincrona, \
  global=org.govway.datasource.runtime.consegnaAsincrona, \
  type=javax.sql.DataSource

# Aggiungi datasource tracciamento
/Server/GlobalNamingResources/Resource:add \
  name=org.govway.datasource.tracciamento.consegnaAsincrona, \
  auth=Container, \
  type=javax.sql.DataSource, \
  driverClassName=${GOVWAY_DS_DRIVER_CLASS}, \
  url=jdbc:postgresql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}?${GOVWAY_TRAC_DS_CONN_PARAM}, \
  username=${GOVWAY_TRAC_DB_USER}, \
  password=${GOVWAY_TRAC_DB_PASSWORD}, \
  maxTotal=${CONSEGNA_ASINCRONA_TRAC_MAX_POOL:-50}

# Collega datasource tracciamento
/Context/ResourceLink:add \
  name=org.govway.datasource.tracciamento.consegnaAsincrona, \
  global=org.govway.datasource.tracciamento.consegnaAsincrona, \
  type=javax.sql.DataSource
```

### Configurazione URL Rewriting

File: `RewriteValve.cli` (vedi directory compose/)

```
# Abilita URL rewriting tramite RewriteValve
/Server/Service/Engine/Host/Valve:add \
  className=org.apache.catalina.valves.rewrite.RewriteValve, \
  configuration=${ENTRYPOINT_D}/rewrite.config
```

## Gestione degli Errori

### Rollback Automatico

Se la validazione XML fallisce dopo l'applicazione delle modifiche, lo strumento ripristina automaticamente il backup:

```bash
# File di backup creati prima della modifica
${CATALINA_HOME}/conf/server.xml-backup
${CATALINA_HOME}/conf/context.xml-backup
```

Vedi implementazione in commons/tomcat9/tomcat-cli.sh:22-33.

### Errori Comuni

**XPath non valido:**
```
XPath non trovato: /Server/Service/InvalidElement
```
Soluzione: Verificare che l'XPath corrisponda a elementi esistenti nell'XML.

**Formato direttiva non valido:**
```
Direttiva invalida: /Server/Service add port=8080
```
Soluzione: Assicurarsi che il formato sia `<xpath>: <operazione> <parametri>` (notare i due punti).

**Operazione non supportata:**
```
Operazione non supportata: modify
```
Soluzione: Usare una delle operazioni supportate: `add`, `top`, `delete`, `write-attribute`, `read-attribute`, `delete-attribute`.

### Debug

Abilitare l'output di debug controllando `/tmp/entrypoint_debug.log` all'interno del container:

```bash
tail -f /tmp/entrypoint_debug.log
```

La classe Java TomcatConfigCli (commons/tomcat9/TomcatConfigCli.java:127-158) stampa informazioni dettagliate su ogni direttiva elaborata.

## Dettagli Implementativi

### Posizione del Sorgente Java

- Tomcat 9: `commons/tomcat9/TomcatConfigCli.java`
- Tomcat 10: `commons/tomcat10/TomcatConfigCli.java`

### Metodi Principali

| Metodo | Riga | Descrizione |
|--------|------|-------------|
| `processDirective()` | 119 | Analizza e instrada la direttiva al gestore appropriato |
| `addElement()` | 188 | Aggiunge elemento come ultimo figlio |
| `addElementAtTop()` | 207 | Aggiunge elemento come primo figlio |
| `deleteElement()` | 229 | Rimuove elemento |
| `writeAttribute()` | 239 | Imposta/aggiorna attributi |
| `readAttribute()` | 253 | Legge attributi (solo output) |
| `deleteAttribute()` | 267 | Rimuove attributi |
| `getElementByXPath()` | 283 | Helper per valutazione XPath |

### Posizione dello Script Shell

- `commons/tomcat9/tomcat-cli.sh`
- `commons/tomcat10/tomcat-cli.sh`

## Differenze dalla CLI di WildFly

Per gli utenti familiari con la CLI di gestione di WildFly, ecco le principali differenze:

| Caratteristica | WildFly CLI | Tomcat CLI |
|----------------|-------------|------------|
| **Sintassi** | `/subsystem=datasources/...` | `/Server/GlobalNamingResources/Resource:add ...` |
| **Protocollo** | Protocollo di gestione nativo | Manipolazione diretta XML |
| **Runtime** | Può modificare il server in esecuzione | Richiede riavvio |
| **Validazione** | Validazione lato server | Validazione schema XML |
| **Operazioni** | Set completo di operazioni | Operazioni CRUD base |
| **XPath** | Non utilizzato | Metodo principale di navigazione |

## Best Practice

1. **Testare le direttive prima su sistemi non di produzione**
   - La validazione XML rileva errori di sintassi ma non problemi semantici

2. **Usare commenti liberamente**
   ```
   # Configura thread pool per produzione
   # Basato su risultati di load testing da ISSUE-1234
   /Server/Executor:add name=prodWorker, maxThreads=500
   ```

3. **Suddividere operazioni complesse in più file**
   ```
   00-executors.cli
   10-connectors.cli
   20-datasources.cli
   30-valves.cli
   ```

4. **Sfruttare le variabili d'ambiente per flessibilità di deployment**
   ```
   /Server/Service/Connector:add port=${HTTP_PORT:-8080}
   ```

5. **Mantenere backup prima di applicare modifiche**
   ```bash
   cp $CATALINA_HOME/conf/server.xml $CATALINA_HOME/conf/server.xml.$(date +%Y%m%d)
   ```

6. **Verificare le modifiche dopo l'applicazione**
   ```bash
   /usr/local/bin/tomcat-cli.sh /tmp/changes.cli
   xmlstarlet sel -t -v "//Connector[@port='9080']/@maxThreads" $CATALINA_HOME/conf/server.xml
   ```

## Risoluzione Problemi

### Modifiche Non Applicate

**Problema:** La CLI viene eseguita senza errori ma le modifiche non compaiono.

**Soluzioni:**
- Verificare che l'XPath corrisponda a elementi esistenti
- Verificare che l'elemento padre esista prima di aggiungere figli
- Rivedere `/tmp/entrypoint_debug.log` per output dettagliato

### Errori di Validazione XML

**Problema:** Le modifiche vengono ripristinate automaticamente dopo l'esecuzione.

**Soluzioni:**
- Controllare la sintassi con `xmlstarlet val $CATALINA_HOME/conf/server.xml`
- Assicurarsi che i valori degli attributi siano correttamente quotati nel file CLI
- Verificare che non vengano creati elementi duplicati

### Fallimenti all'Avvio del Container

**Problema:** Il container non si avvia dopo le modifiche CLI.

**Soluzioni:**
- Controllare i log di Tomcat: `docker logs govway-container`
- Verificare che gli URL dei datasource siano raggiungibili
- Assicurarsi che le porte non siano già in uso
- Validare che i nomi delle risorse JNDI corrispondano alle aspettative dell'applicazione

## Vedi Anche

- [GovWay Docker README](README.md)
- [Apache Tomcat Configuration Reference](https://tomcat.apache.org/tomcat-9.0-doc/config/)
- [XPath Tutorial](https://www.w3schools.com/xml/xpath_intro.asp)
- [XMLStarlet Documentation](http://xmlstar.sourceforge.net/doc/UG/xmlstarlet-ug.html)

## File Correlati

- `commons/tomcat9/entrypoint.sh:440,463` - Elaborazione automatica file CLI
- `commons/tomcat9/initgovway.sh` - Inizializzazione GovWay con CLI
- `integrationmanager.cli` - Configurazione datasource Integration Manager
- `consegnaAsincrona.cli` - Configurazione datasource consegna asincrona
- `compose/RewriteValve.cli` - Esempio URL rewriting
