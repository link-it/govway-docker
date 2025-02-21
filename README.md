# Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker. L'ambiente consente di produrre immagini in due modalità:
- **standalone** : in questa modalità l'immagine contiene oltre al gateway anche un database HSQL con persistenza su file, dove vengongono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **orchestrate** : in questa modalità l'immagine viene preparata in modo da collegarsi ad un database esterno

## Build immagine Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto è presente uno script di shell che si occupa di prepare il buildcontext e di avviare il processo di build con tutti gli argomenti necessari. 

Lo script può essere avviato senza parametri per ottenere il build dell'immagine di default, ossia una immagine in modalità standalone realizzata a partire dalla release binaria disponibile su GitHub.

Eseguendo invece lo scropt con il parametro '-h' è possibile conoscere i parametri di personalizzazione esistenti.

## Avvio immagine Docker

Una volta eseguito il build dell'immagine tramite lo script fornito, l'immagine puo essere eseguita con i normali comandi di run docker:
```shell
./build_image.sh 

docker run \
  -v ~/govway_log:/var/log/govway -v ~/govway_conf:/etc/govway \
  -e GOVWAY_POP_DB_SKIP=false \
  -e GOVWAY_DEFAULT_ENTITY_NAME=Ente \
  -p 8080:8080 \
  -p 8081:8081 \
  -p 8082:8082 \
linkitaly/govway:3.3.16

```

In modalità orchestrate al termine delle operazioni di build, lo script predispone uno scenario di test avviabile con docker-compose, all'interno della directory **"compose"**; lo scenario di test può quindi essere avviato come segue:

```
./build_image.sh -d postgresql
cd compose
docker compose up
```

Sotto la directory compose vengono create le sottodirectories **govway_conf** e **govway_log**, su cui il container montera' i path _**/etc/govway**_ ed _**/var/log/govway**_  rispettivamente.
L'accesso è previsto in protocollo HTTP sulle porte _**8080, 8081, 8082**_ .

## Informazioni di Base

### File interni all'immagine

A prescindere dalla modalità di costruzione dell'immagine, vengono utilizzati i seguenti path:
- **/etc/govway** path le properties di configurazione (riconfigurabile al momento del build). 
- **/var/log/govway** path dove vengono scritti i files di log (riconfigurabile al momento del build).

Se l'immagine è stata prodotta in modalità standalone: 
- **/opt/hsqldb-2.7.1/hsqldb/database** database interno HSQL 

si possono rendere queste location persistenti, montando dei volumi su queste directory.

### Servizi attivi

Le immagini prodotte utilizzano come application server ospite WildFly 26.1.3.Final, in ascolto per default sia in protocollo _**AJP**_ sulla porta **8009** sia in _**HTTP**_ su 3 porte in modo da gestire il traffico su ogni porta, con un listener dedicato:
- **8080**: Listener dedicato al traffico in erogazione (max-thread-pool default: 100)
- **8081**: Listener dedicato al traffico in fruizione (max-thread-pool default: 100)
- **8082**: Listener dedicato al traffico di gestione (max-thread-pool default: 20)

E' possibile personalizzare i listener da attivare tramite variabili d'ambiente descritte nei paragrafi successivi.
Tutte queste porte sono esposte dal container e per accedere ai servizi dall'esterno si devono pubblicare al momento dell'avvio del immagine. 
Le interfacce web di monitoraggio configurazione sono quindi disponibili sulle URL:

```
 http://<indirizzo IP>:8082/govwayConsole/
 http://<indirizzo IP>:8082/govwayMonitor/
```
L'account di default per l'interfaccia **govwayConsole** è:
 * username: amministratore
 * password: 123456

L'account di default per l'interfaccia **govwayMonitor** è:
 * username: operatore
 * password: 123456

Il contesto di accesso ai servizi dell`API gateway per le erogazioni di API:
```
 http://<indirizzo IP>:8080/govway/
```

Il contesto di accesso ai servizi dell`API gateway per le fruizioni di API:
```
 http://<indirizzo IP>:8081/govway/
```

### Script SQL di inizializzazione della Base Dati 

All'avvio del container, sia in modalità standalone che con immagini orchestrate, vengono eseguite delle verifiche sul database per assicurarne la raggiungibilità ed il corretto popolamento; in caso venga riconosciuto uno o più database non inizializzati è possibile utilizzare gli scripts SQL interni per effettuare l'inizializzazione, valorizzando la variabile **'GOVWAY_POP_DB_SKIP'** al valore **false**.

Se si vuole esaminare gli script o utilizzarli manualmente, è possibile recuperarli dall'immagine in una delle directory standard  **/opt/hsql**, **/opt/postgresql** o **/opt/oracle**.  Ad esempio per l'immagine che utilizza un database 'postgresql' è possibile utilizzare il comando:

```shell
CONTAINER_ID=$(docker run -d -e GOVWAY_DEFAULT_ENTITY_NAME=Ente linkitaly/govway:3.3.16_postgres initsql)
docker cp ${CONTAINER_ID}:/opt/postgresql .
```

### Comandi di inizializzazione aggiuntiva

La sequenza di avvio avvio del container, sia in modalità standalone che con immagini orchestrate, consente di valutare dei comandi di inizializzazione aggiuntiva, inserendoli sotto la directory **/docker-entrypoint-govway.d/**

Tutti i files trovati sotto quella directory vengono valutati in ordine alfabetico, suddivisi e gestiti come segue:
- files con estensione **'.sh'** non eseguibili:  vengono trattati come scripts di shell e viene fatto il source del contenuto (import nella shell attuale)
- files con estensione **'.sh'** eseguibili:  vengono eseguiti con l'utente di sistema **wildfly** o **tomcat**
- files con estensione **'.cli'**: vengono trattati come script di command line wildfly e vengono passati all 'interprete **${JBOSS_HOME}/bin/jboss-cli.sh** o **/usr/local/bin/tomcat-cli.sh**
- tutti gli altri files : vengono ignorati

La valutazione dei comandi di inizializzazione viene fatta dopo le verifiche e l'eventuale inizializzazione del database, ma prima dell'avvio dell'application server; inoltre la valutazione avviene solamente al primo avvio del container. 

Qualsiasi errore generato da uno qualsiasi dei comandi eseguiti viene ignorato, ed il processo di valutazione avanza al file successivo.

## Informazioni sulle immagini batch
Utilizzando lo switch "-a" dello script di build è possibile costruire una immmagine contenente solamente il software necessario all'esecuzione dei batch di generazione statistiche.
Questo tipo di immagini si differenzia dalle immagini run, manager e full per il fatto che non viene istanziato un server che rimane in ascolto, ma viene eseguito un singolo task destinato a terminare in un tempo finito.

### Tipo di statistiche da generare ###
Il batch è in grado di generare le statistiche orarie e giornaliere; il tipo di statistiche da generare si decide attraverso un'argomento passato a runtime. 

Viene verificata la corrispondenza dell'argomento con uno di questi due pattern **"[oO]rari[ea]"** , **"[gG]iornalier[ea]"**
Se non viene passato alcun argomento il default è orarie
Es:
```bash
docker run 
-e <VARIABILI_DI_CONFIGURAZIONE> \
.... \
linkitaly/govway:3.3.16_postgres_batch_postgres giornaliera
```

### Modalita Cron ###
Il batch è stato creato per essere eseguito da uno schedulatore orchestrato (es Cronjobs kubernetes), quindi la schedulazione è demandata a questi sistemi. 

Se non disponibile è possibile abilitare la modalità cron. In questa modalità, il container creato schedula autonomamente l'esecuzione del batch; inoltre è possibile indicare con quali intervallo eseguire il batch.

## Personalizzazioni
Attraverso l'impostazione di alcune variabili d'ambiente note è possibile personalizzare alcuni aspetti del funzionamento dei container. Le variabili supportate al momento sono queste:

* GOVWAY_DEFAULT_ENTITY_NAME: Indica il nome del soggetto di default utilizzato  (Obbligatorio)

### Controlli all'avvio del container

A runtime il container esegue i controlli di: raggiungibilita del database, di popolamento del database e di avvio di govway. Questi controlli possono essere abilitati o meno impostando le seguenti variabili d'ambiente:

* GOVWAY_LIVE_DB_CHECK_SKIP: Salta il controllo di raggiungibilità dei server database allo startup (default: FALSE)

* GOVWAY_READY_DB_CHECK_SKIP: Salta il controllo di popolamento dei database allo startup (default: FALSE)

* GOVWAY_STARTUP_CHECK_SKIP: Salta il controllo di avvio di govway allo startup (default: FALSE)

* GOVWAY_POP_DB_SKIP: Salta il popolamento automatico delle tabelle (default: TRUE)

E' possibile personalizzare il ciclo di controllo di raggiungibilità dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_LIVE_DB_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare la prima verifica (default: 0)
* GOVWAY_LIVE_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione faallito ed il successivo (default: 2)
* GOVWAY_LIVE_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 30)
* GOVWAY_LIVE_DB_CHECK_CONNECT_TIMEOUT: Timeout di connessione al server, in secondi (default: 5)


E' possibile personalizzare il ciclo di controllo di popolamento dei server database impostando le seguenti variabili d'ambiente:
* GOVWAY_READY_DB_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un tentativo di connessione faallito ed il successivo (default: 2)
* GOVWAY_READY_DB_CHECK_MAX_RETRY: Numero massimo di tentativi di connessione (default: 5)


E' possibile personalizzare il ciclo di controllo di avvio di govway impostando le seguenti variabili d'ambiente:
* GOVWAY_STARTUP_CHECK_FIRST_SLEEP_TIME: tempo di attesa, in secondi, prima di effettuare il primo controllo (default: 20)
* GOVWAY_STARTUP_CHECK_SLEEP_TIME: tempo di attesa, in secondi, tra un controllo fallito ed il successivo  (default: 5)
* GOVWAY_STARTUP_CHECK_MAX_RETRY: Numero massimo di controlli effettuati (default: 60)

### Connessione a database esterni 

* GOVWAY_DS_JDBC_LIBS: path sul filesystem del container, ad una directory dove sono contenuti uno o più file jar necessari per l'interfacciamento al database
di cui almeno uno deve implementare l'interfaccia JDBC java.sql.Driver (obbligatorio per tutti i database tranne HSQL)

  ***AVVISO COMPORTAMENTO DEPRECATO: le immagini PostgreSQL al momento contengono un driver JDBC interno, che viene utilizzato per le connessioni JDBC. Nelle prossime versioni, il driver interno sarà eliminato e sara quindi obbligatorio fornire le librerie attraverso la variabile GOVWAY_DS_JDBC_LIBS***
  
* GOVWAY_DB_SERVER: nome dns o ip address del server database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_NAME: Nome del database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_USER: username da utiliizare per l'accesso al database (obbligatorio in modalita orchestrate)
* GOVWAY_DB_PASSWORD: password di accesso al database (obbligatorio in modalita orchestrate)

Se la configurazione lo richiede è possibile suddividere i dati prodotti o utilizzati da govway, su piu' database, a seconda della categoria di dati contenuti.
Le categorie di dati gestite sono:  CONFIGURAZIONE, TRACCIAMENTO e STATISTICHE.

E' possibile quindi, aggiungere puntamenti ai database, indicando in aggiunta al set di variabili indicato in precedenza, uno o piu di quelli indicati di seguito:  

CONFIGURAZIONE
* GOVWAY_CONF_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_CONF_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_CONF_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_CONF_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

STATISTICHE
* GOVWAY_STAT_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_STAT_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_STAT_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_STAT_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

TRACCIAMENTO
* GOVWAY_TRAC_DB_SERVER (default: GOVWAY_DB_SERVER)
* GOVWAY_TRAC_DB_NAME (default: GOVWAY_DB_NAME)
* GOVWAY_TRAC_DB_USER (default: GOVWAY_DB_USER)
* GOVWAY_TRAC_DB_PASSWORD (default: GOVWAY_DB_PASSWORD)

#### Connessione a database Oracle ####
Quando ci si connette ad un database esterno Oracle devono essere indicate anche le seguenti variabili d'ambiente

* GOVWAY_ORACLE_JDBC_URL_TYPE (SID/SERVICENAME): indica se connettersi ad un SID o ad un ServiceName Oracle (default: SERVICENAME)
* ~GOVWAY_ORACLE_JDBC_PATH: path sul filesystem del container, al driver jdbc da utilizzare~ **[DEPRECATA in favore di GOVWAY_DS_JDBC_LIBS]**

### Pooling connessioni database

E' possibile personalizzare alcuni aspetti relativi ai datasource utilizzati da GovWay per accedere al database; per farlo si possono impostare i valori delle variabili d'ambiente elencate di seguito:

* GOVWAY_MAX_POOL: Numero massimo di connessioni stabilite (default: 10)
* GOVWAY_MIN_POOL: Numero minimo di connessioni stabilite (default: 2)
* GOVWAY_INITIALSIZE_POOL: Numero di connessioni stabilite ad inizializzazione del datasource (default: 2)
* GOVWAY_DS_BLOCKING_TIMEOUT: Tempo di attesa, im millisecondi, per una connessione libera dal pool (default: 30000)
* GOVWAY_DS_IDLE_TIMEOUT: Tempo trascorso, in minuti, prima di eliminare una connessione dal pool per inattivita (default: 5)
* GOVWAY_DS_CONN_PARAM: parametri JDBC aggiuntivi (default: vuoto)
* GOVWAY_DS_PSCACHESIZE: dimensione della cache usata per le prepared statements (default: 20)

Se la configurazione di GovWay prevede di suddividere i dati su più database (configurazione, tracciamento e statistiche) è possibile personalizzare i datasource in funzione dello specifico database, utilizzando le seguenti variabili.

Datasource TRACCIAMENTO
* GOVWAY_TRAC_MAX_POOL (default: 50)
* GOVWAY_TRAC_MIN_POOL (default: 2)
* GOVWAY_TRAC_INITIALSIZE_POOL (default: 2)
* GOVWAY_TRAC_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_TRAC_DS_CONN_PARAM (default: vuoto)
* GOVWAY_TRAC_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_TRAC_DS_PSCACHESIZE (default: 20)

Datasource CONFIGURAZIONE
* GOVWAY_CONF_MAX_POOL (default: 10)
* GOVWAY_CONF_MIN_POOL (default: 2)
* GOVWAY_CONF_INITIALSIZE_POOL (default: 2)
* GOVWAY_CONF_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_CONF_DS_CONN_PARAM (default: vuoto)
* GOVWAY_CONF_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_CONF_DS_PSCACHESIZE (default: 20)

Datasource STATISTICHE
* GOVWAY_STAT_MAX_POOL (default: 5)
* GOVWAY_STAT_MIN_POOL (default: 1)
* GOVWAY_STAT_INITIALSIZE_POOL (default: 1)
* GOVWAY_STAT_DS_BLOCKING_TIMEOUT (default: 30000)
* GOVWAY_STAT_DS_CONN_PARAM (default: vuoto)
* GOVWAY_STAT_DS_IDLE_TIMEOUT (default: 5)
* GOVWAY_STAT_DS_PSCACHESIZE (default: 20)


### Configurazione Listener 
Per configurare con quali protocolli i listener di wildfly accetteranno le richieste, è possibile utilizzare le seguenti variabili:

* GOVWAY_AS_AJP_LISTENER: Abilita o disabilita i listener AJP  (default: ajp-8009, valori ammissibili [true, false, ajp-8009] )
* GOVWAY_AS_HTTP_LISTENER: Abilita o disabilita i listener HTTP (default: true, valori ammissibili [true, false, http-8080] )

A seconda del protocollo che si vuole configurare, valorizzando la relativa variabile a **true** si abiliteranno tutti e tre listener previsti di erogazione, fruizione e gestione. Viceversa valorizzando a **false** i tre listener verranno disabilitati.
Utilizzando i valori speciali **http-8080** o **ajp-8009** verrà abilitato un solo un listener per il protocollo scelto, sulla rispettiva porta di default.


I listener possono essere ulteriormente configurati tramite le seguenti variabili:

* GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in erogazione, (default: 100) 
* GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in fruizione, (default: 100) 
* GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico di gestione, (default: 20)

* GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in erogazione, (default: 100) 
* GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il  traffico in fruizione, (default: 100) 
* GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico di gestione, (default: 20)

* GOVWAY_AS_MAX_POST_SIZE: Dimensione massima consentita per il body dei messaggi. Si applica a tutti i listener abilitati (default: 10485760 bytes)
* GOVWAY_AS_MAX_HTTP_SIZE: Dimensione massima cumulata di tutti gli header http inviati. Si applica a tutti i listener abilitati (default: 10485760 bytes)

### Avviso variabili deprecate
Di seguito una lista di variabili usate in precedenza per la configurazione dei Listener. Queste variabili sono state deprecate e verrano rimosse nelle versioni successive:

* ~WILDLFY_AJP_LISTENER: Abilita o disabilita i listener AJP  (default: ajp-8009, valori ammissibili [true, false, ajp-8009] )~ **[DEPRECATA in favore di GOVWAY_AS_AJP_LISTENER]**
* ~WILDLFY_HTTP_LISTENER: Abilita o disabilita i listener HTTP (default: true, valori ammissibili [true, false, http-8080] )~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_LISTENER]**

* ~WILDFLY_HTTP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in erogazione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_IN_WORKER_MAX_THREADS]**
* ~WILDFLY_HTTP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico in fruizione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_OUT_WORKER_MAX_THREADS]**
* ~WILDFLY_HTTP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener HTTP per il traffico di gestione, (default: 20)~ **[DEPRECATA in favore di GOVWAY_AS_HTTP_GEST_WORKER_MAX_THREADS]**

* ~WILDFLY_AJP_IN_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico in erogazione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_IN_WORKER_MAX_THREADS]**
* ~WILDFLY_AJP_OUT_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il  traffico in fruizione, (default: 100)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_OUT_WORKER_MAX_THREADS]**
* ~WILDFLY_AJP_GEST_WORKER_MAX_THREADS: impostazione del numero massimo di thread, sul worker del listener AJP per il traffico di gestione, (default: 20)~ **[DEPRECATA in favore di GOVWAY_AS_AJP_GEST_WORKER_MAX_THREADS]**
* ~WILDFLY_MAX_POST_SIZE: Dimensione massima consentita per i messaggi. Si applica a tutti i listener abilitati (default: 10485760 bytes)~ **[DEPRECATA in favore di GOVWAY_AS_MAX_POST_SIZE]**

### Configurazioni avanzate  
* WILDFLY_SUSPEND_TIMEOUT: Tempo massimo di attesa per la chiusura delle richiesta attive in fase di spegnimento di wildfly. Non ha effetti per le immagini che usano Tomcat. (default: 20s)
* GOVWAY_JVM_AGENT_JAR: Path ad un jar agent da caricare all'avvio dell'application server (Ex OpenTelemetry)
* GOVWAY_UUID_ALG: Algoritmo utilizzato internamente per la generazione degli UUID. (default: v1, valori ammissibili [v1, v4, {ID Algoritmo}] )

  La lista degli algoritmi utilizzabili si puo recuperare dal file __govway.classRegistry.properties__  dalle proprietà del tipo **org.openspcoop2.id.{ID Algoritmo}**. Inoltre si possono utilizzare le seguenti abbreviazioni:
  - v1 o V1 ->  UUIDv1 
  - v4 o V4 ->  UUIDv4sec

## Personalizzazioni Batch

### Modalita Cron

* GOVWAY_BATCH_USA_CRON: indica se abilitare la modalità cron (default: no , valori ammissibili [si, yes, 1, true])
* GOVWAY_BATCH_INTERVALLO_CRON: indica l'intervallo di schedulazione del batch in minuti (default: 5 per statistiche orarie | 30 per statisiche giornaliere) 


### Connessione a database esterni 

Il batch richiede l'accesso alle tabelle che memorizzano i dati delle seguenti categorie CONFIGURAZIONE, TRACCIAMENTO e STATISTICHE.
Per default si suppone che queste siano presenti sullo stesso database indicato dalle seguenti variabili obbligatorie:

* GOVWAY_DS_JDBC_LIBS: path sul filesystem del container, ad una directory dove sono contenuti uno o più file jar necessari per l'interfacciamento al database
di cui almeno uno deve implementare l'interfaccai JDBC java.sql.Driver (obbligatorio solo per tutti i database tranne HSQL)

  ***AVVISO COMPORTAMENTO DEPRECATO: le immagini PostgreSQL al momento contengono un driver JDBC interno, che viene utilizzato per le connessioni JDBC. Nelle prossime versioni, il driver interno sarà eliminato e sara quindi obbligatorio fornire le librerie attraverso la variabile GOVWAY_DS_JDBC_LIBS***

* GOVWAY_STAT_DB_SERVER: nome dns o ip address del server database (obbligatorio)
* GOVWAY_STAT_DB_NAME: Nome del database delle statistiche (obbligatorio)
* GOVWAY_STAT_DB_USER: username da utilizzare per l'accesso al database (obbligatorio)
* GOVWAY_STAT_DB_PASSWORD: password di accesso al database (obbligatorio)
  
Se la configurazione lo richiede è possibile
indicare puntamenti differenti per le tabelle delle restanti categorie, usando i seguenti set di variabili

CONFIGURAZIONE
* GOVWAY_CONF_DB_SERVER (default: GOVWAY_STAT_DB_SERVER)
* GOVWAY_CONF_DB_NAME (default: GOVWAY_STAT_DB_NAME)
* GOVWAY_CONF_DB_USER (default: GOVWAY_STAT_DB_USER)
* GOVWAY_CONF_DB_PASSWORD (default: GOVWAY_STAT_DB_PASSWORD)

TRACCIAMENTO
* GOVWAY_TRAC_DB_SERVER (default: GOVWAY_STAT_DB_SERVER)
* GOVWAY_TRAC_DB_NAME (default: GOVWAY_STAT_DB_NAME)
* GOVWAY_TRAC_DB_USER (default: GOVWAY_STAT_DB_USER)
* GOVWAY_TRAC_DB_PASSWORD (default: GOVWAY_STAT_DB_PASSWORD)

#### Connessione a database Oracle ####
Quando ci si connette ad un database esterno Oracle devono essere indicate anche le seguenti variabili d'ambiente

* GOVWAY_ORACLE_JDBC_URL_TYPE (SID/SERVICENAME): indica se connettersi ad un SID o ad un ServiceName Oracle (default: SERVICENAME)
* ~GOVWAY_ORACLE_JDBC_PATH: path sul filesystem del container, al driver jdbc da utilizzare~ **[DEPRECATA in favore di GOVWAY_DS_JDBC_LIBS]**


### Configurazioni avanzate
* GOVWAY_JVM_AGENT_JAR: Path ad un jar agent da caricare all'avvio dell'applicazione (Ex. OpenTelemetry)
