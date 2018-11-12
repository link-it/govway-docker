##### Immagine docker per GovWay

Questo progetto fornisce tutto il necessario per produrre un'ambiente di prova GovWay funzionante, containerizzato in formato Docker
L'ambiente e' reso disponible in due modalità:
- **standalone** : in questa modalità l'immagine contiene oltre al gateway anche un database HyperSQL con persistenza su file,dove vengongono memorizzate le configurazioni e le informazioni elaborate durante l'esercizio del gateway.
- **compose** : in questa modalità l'immagine viene preparata in modo da collegarsi ad un database Potsgres esterno

### Docker
Per semplificare il più possibile la preparazione dell'ambiente, sulla root del progetto sono presenti due script di shell che si occupano di prepare tutti i files necessari al build dell'immagine e ad avviare il processo di build. 
Gli script possono essere avviati senza parametri per ottenere il build dell'immagine di defult; in alternativa e' possibile fare alcune personalizzazioni impostando oopportunamente i parametri, come descritti qui di seguito:

- **build_standalone.sh** : esegue il build dell'immagine in modalità standalone
```
./build_standalone.sh -h
Usage build_standalone.sh [ -s | -h | -t <tagname> | -v <versione> ]

Options
-s : Esegue build a partire dai sorgenti presenti nel repository GitHub
-t : Imposta il nome del TAG che verra' utilizzato per l'immagine prodotta 
-v : Imposta la versione di govway da utilizzare per il build al posto di quella di default (3.0.1.rc1)
-h : Mostra questa pagina di aiuto
```

- **build_compose.sh** : esegue il build dell'immagine in modalità compose
```
./build_compose.sh -h
Usage build_compose.sh [ -s | -h | -v <versione> ]

Options
-s : Esegue build a partire dai sorgenti presenti nel repository GitHub
-v : Imposta la versione di govway da utilizzare per il build al posto di quella di default (3.0.1.rc1)
-h : Mostra questa pagina di aiuto
```

Quando viene eseguit il build in modalita' compose, gli script SQL necessari ad inizializzare il database possono essere recuperati direttamente dall immagine nella directory /database; ad esempio utilizzando il seguente comando:

```
docker cp <container ID:/database/GovWay_setup.sql . 
```
