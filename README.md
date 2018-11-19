# Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker
L'ambiente è reso disponible in due modalità:
- **standalone** : in questa modalità l'immagine contiene oltre al gateway anche un database HyperSQL con persistenza su file, dove vengongono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **compose** : in questa modalità l'immagine viene preparata in modo da collegarsi ad un database Potsgres esterno

## Build immagine Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto sono presenti due script di shell che si occupano di prepare tutti i files necessari al build dell'immagine e ad avviare il processo di build. 
Gli script possono essere avviati senza parametri per ottenere il build dell'immagine di defult; in alternativa è possibile fare alcune personalizzazioni impostando oopportunamente i parametri, come descritti qui di seguito:

```
Usage build_[ standalone | compose ].sh [ -s | -h | -t <tagname> | -v <versione> ]

Options
-s : Esegue build a partire dai sorgenti presenti nel repository GitHub
-t : Imposta il nome del TAG che verrà utilizzato per l'immagine prodotta 
-v : Imposta la versione di govway da utilizzare per il build al posto di quella di default (3.0.1.rc2)
-h : Mostra questa pagina di aiuto
```

Quando viene eseguito il build in modalità compose, gli script SQL necessari ad inizializzare il database possono essere recuperati direttamente dall'immagine nella directory /database; ad esempio utilizzando il seguente comando:


```
docker cp <Container ID>:/database/GovWay_setup.sql . 
```

## Avvio immagine Docker

Una volta eseguito il build dell'immagine tramite uno degli script forniti, l'immagine puo essere eseguita con i normali comandi di run docker; Ad esempio:
```
./build_standalone.sh -t govway_standalone:3.0.1.rc2
docker run -p 8080:8080 govway_standalone:3.0.1.rc2
```

oppure in modalità compose

```
./build_compose.sh -t govway_compose:3.0.1.rc2
cd target 
docker-compose up
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
Oltre all´accesso standard in HTTP le immagini consentono di configurare dinamicamente un connettore HTTPS in ascolto sulla porta 8443; il connettore generato utilizzerà un keystore ed un truststore contenente dei certificati generati all`avvio del server.
Per avviare la generazione di chiavi RSA e certificati si deve montare, all´avvio del container, un volume vuoto sulla directory standard **/etc/govway/pki**; ad esempio:

```
mkdir ~/certificati_govway
docker run -v ~/certificati_govway:/etc/govway/pki -p 8080:8080 -p 8443:8443 govway_standalone:3.0.1.rc2
```
Un volta avviato il container tutte gli accessi descritti in precedenza saranno disponibili su protocollo HTTPS ed il server si presentera con un certificato server col subject: 
**_CN=govway_server.test.it,O=govway.org,C=it_** 

emesso dalla Certification Authority:
**_CN=GovWay CA,O=govway.org,C=it_** .

Tutti i files generati all`avvio sono disponibili nella directory **_~/certificati_govway/CA_govway_server/ca_** ; in particolare sarà possibile trovare: i certificati Server e Client, le relative chiavi private e le password utilizzate per porteggerle. Di seguito una breve descrizione dei files generati:

Nella sottodirectory _certs/_
- **ca_govway_server.cert.pem** : Certificato x509 della CA comune a tutti i certificati
- **ee_govway_server.test.it.cert.pem** : Certificato server utilizzato dal connettore HTTPS
- **ee_govway_server_Client_1.cert.pem** : Certificato client numero 1 da utilizzare per test della piattaforma
- **ee_govway_server_Client_2.cert.pem** : Certificato client numero 2 da utilizzare per test della piattaforma

Nella sottodirectory _private/_
- **ca_govway_server.key.pem** : Chiave privata RSA da accoppiare al certificato della CA comune
- **ca_govway_server.README.txt** :  password utilizzata per la protezione della chiave privata della CA
- **ee_govway_server.test.it.key.pem** : Chiave privata RSA da accoppiare al certificato client numero 1
- **ee_govway_server.test.it.README.txt** : password utilizzata per la protezione della chiave privata del certificato server
- **ee_govway_server_Client_1.key.pem** : Chiave privata RSA da accoppiare al certificato client numero 1
- **ee_govway_server_Client_1.README.txt** : password utilizzata per la protezione della chiave privata del certificato client numero 1
- **ee_govway_server_Client_2.key.pem** : Chiave privata RSA da accoppiare al certificato client numero 1
- **ee_govway_server_Client_2.README.txt** : password utilizzata per la protezione della chiave privata del certificato client numero 2

Utilizzando i files descritti in precedenza vengono generati un keystore ed un truststore di tipo JKS; questi sono riferiti nella definizione del connettore HTTPS utilizzato dal server. I keystores sono i seguenti :

- **_~/certificati_govway/keystore_server.jks_**
- **_~/certificati_govway/truststore_server.jks_**




