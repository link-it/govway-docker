# Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker. L'ambiente è reso disponible in due modalità:
- **standalone** : in questa modalità l'immagine contiene oltre al gateway anche un database HSQL con persistenza su file, dove vengongono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **compose** : in questa modalità l'immagine viene preparata in modo da collegarsi ad un database Potsgres esterno

## Build immagine Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto sono presenti due script di shell che si occupano di prepare tutti i files necessari al build dell'immagine e ad avviare il processo di build. 
Gli script possono essere avviati senza parametri per ottenere il build dell'immagine di default; in alternativa è possibile fare alcune personalizzazioni impostando opportunamente i parametri, come descritti qui di seguito:

```
Usage build_standalone.sh [ -t <repository>:<tagname> | [ -v <versione> | -b <branch> ] | -h ]

Options
-t : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-v : Imposta la versione dell'installer binario di govway da utilizzare per il build (default :3.3.4.p1)
-b : Imposta il branch su github da utilizzare per il build (incompatibile con -v)
-h : Mostra questa pagina di aiuto
```

I files interni utilizzati da GovWay: le properties di configurazione, i certificati SSL di esempio, il database HSQL (usato in modalita standalone) ed i file di log, sono posizionati tutti sotto la directory standard **/var/govway**; si possono quindi rendere tutti persistenti montando un volume vuoto su questa directory.
 
 Il container tomcat utilizzato per il deploy di govway rimane in ascolto sia in protocollo _**HTTP**_ sulla porta **8080** che in _**HTTPS**_ sulla porta **8443**; queste porte sono esposte dal container e per accedere ai servizi dall'esterno, si devono pubblicare al momento dell'avvio del immagine

Il database viene inizializzato all'avvio del container, sia in modalià standalone che in modaliatà compose; comunque è possibile esaminare lo script SQL, o riutilizzarlo per un'altro database, recuperandolo dall'immagine alla directory standard  **/database**.

## Avvio immagine Docker

Una volta eseguito il build dell'immagine tramite uno degli script forniti, l'immagine puo essere eseguita con i normali comandi di run docker:
```
./build_standalone.sh -t govway_standalone:3.3.4.p1
docker run -v ~/govway_home:/var/govway -p 8080:8080 -p 8443:8443 govway_standalone:3.3.4.p1
```

In modalità compose

```
./build_compose.sh -t govway_compose:3.3.4.p1
cd target 
docker-compose up
```

In questa modalità la personalizzazione dei volumi e la pubblicazione delle porte non può essere fatta a linea di comando ma deve essere fatta necessariamente editando il file **docker-compose.yml** che si trova nella directory target generata dallo script di build.
Nel caso che il file non venga editato, per default verranno pubblicate le porte _**8080**_ e _**8443**_.
Inoltre nella directory corrente verra' creata la sottodirectory **govway_home**, su cui il container montera' il path _**/var/govway**_

### Personalizzazioni
Attraverso l'impostazione di alcune variabili d'ambiente note è possibile personalizzare alcuni aspetti del funzionamento del container. Le variabili supportate al momento sono queste:
* FQDN: utilizzato per personalizzare il campo CN del subject dei certificati generati; se non specificato viene usato il valore di default **test.govway.org**
* USERID: utilizzato per impostare l'id di sistema dell'utente tomcat
* GROUPID: utilizzato per impostare l'id di sistema dell'utente tomcat
* SSH_PUBLIC_KEY: utilizzato per registrare una chiave pubblica ,tra gli host autorizzati a collegarsi al server SSH interno
* GOVWAY_INTERFACE: utilizzato per pilotare il set di interfacce da utilizzare per configurazione o monitoraggio. I valori possibili sono ***web*** o ***rest**


L'avvio tipico in modalità standalone è il seguente:
```
docker run \
 -v ~/govway_home:/var/govway \
 -p 8080:8080 -p 8443:8443 -p 2222:22 \
 -e "FQDN=`hostname -f`" -e "USERID=`id -u $USER`" -e "GROUPID=`id -g $USER`" -e "SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)" \
 govway_standalone:3.3.4.p1
```

in modalità compose si deve editare la sezione "_**environment**_" del file docker-compose.yml e valorizzare le variabili eseguendo prima i comandi sulla shell del sistema host e sostituendo i rispettivi risultati. Ad esempio
```
...
    - USERID=1234
    - GROUPID=1234
    - FQDN=docker_instance.govway.org
    - SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABI......"
...
```

## Accessi standard
Le immagini costruite, per default sono in ascolto sulla porta TCP 8080 in protocollo HTTP. Le interfacce web di monitoraggio configurazione sono quindi disponibili sulle URL:
```
 http://<indirizzo IP>:8080/govwayConsole/
 http://<indirizzo IP>:8080/govwayMonitor/
```
L'account di default per l'interfaccia **govwayConsole** è
 * username: amministratore
 * password: 123456

L'account di default per l'interfaccia **govwayMonitor** è
 * username: operatore
 * password: 123456

Il contesto di accesso ai aservizi dell`API gateway è invece il seguente:
```
 http://<indirizzo IP>:8080/govway/
```

### Configurazione HTTPS
Oltre all´accesso standard in HTTP le immagini consentono di configurare dinamicamente un connettore HTTPS in ascolto sulla porta 8443; il connettore generato utilizzerà un keystore ed un truststore contenente dei certificati generati all`avvio del server. Tutti i files relativi alla comunicazione HTTPS vengono posizionate nella directory standard **/var/govway/pki**

Un volta avviato il container tutte gli accessi descritti in precedenza saranno disponibili su protocollo HTTPS ed il server si presenterà con un certificato server col subject: 
**_CN=test.govway.org,O=govway.org,C=it_** 

emesso dalla Certification Authority:
**_CN=GovWay CA,O=govway.org,C=it_** .

La certification Authority utilizzata per generare tutti i files si trova nella sottodirectory **_CA_test/ca_** ; in particolare sarà possibile trovare: i certificati Server e Client, le relative chiavi private e le password utilizzate per porteggerle. 

Nella sottodirectory _**esempi/**_ sono disponibili i certificati e le chiavi private di esempio, organizzate per funzione (client e server)
- esempi/test_Client_1 e esempi/test_Client_2 e 
  - **ca_test.cert.pem** : Certificato x509 della CA comune a tutti i certificati
  - **ee_test_Client_X.cert.pem** : Certificato client numero 1 da utilizzare per test della piattaforma
  - **ee_test_Client_X.key.pem** : Chiave privata RSA da accoppiare al certificato client numero 1
  - **ee_test_Client_X.README.txt** : password utilizzata per la protezione della chiave privata del certificato

- esempi/test.govway.org
  - **ca_test.cert.pem** : Certificato x509 della CA comune a tutti i certificati
  - **ee_test.govway.org.cert.pem** : Certificato server relativo al FQDN
  - **ee_test.govway.org.key.pem** : Chiave privata RSA da accoppiare al certificato server
  - **ee_test_.govway.org.README.txt** : password utilizzata per la protezione della chiave privata del certificato

Nella sottodirectory _**stores/**_ chiavi e certificati sono raccolti in keystore utilizzati dal server tomcat per configurare il connettore HTTPS
  - **keystore_server.jks** : Contiene chiave privata e certificato relativo al FQDN
  - **truststore_server.jks**: Contiene il certifica della CA emettitrice di tutti i certificati di esempio
  - **keystore_server.README.txt**: Password del keystore e della chiave privata

### Script SQL
Lo script SQL necessario ad inizializzare il database si trova nell'immagine alla directory standard **/database**; Per recuperalo si possono utilizzare i seguenti comandi :

```
docker run govway_compose:3.3.4.p1 true
docker cp <Container ID>:/database/GovWay_setup.sql .
```


