# CreateUser

Kommenteret Bash-script til Ubuntu/Debian, der opretter lokale Linux-brugere ud fra en kommasepareret CSV-fil. Velegnet til undervisning og laboratoriemiljøer.

## Installation

```bash
sudo apt update
sudo apt install git passwd
git clone https://github.com/ibhelmer/CreateUser.git
cd CreateUser
chmod +x create_users.sh
```

## CSV-format

Filen skal være UTF-8 med følgende header:

```csv
fullname,username,group,email
Anna Jensen,anna,lab_students,anna@example.com
Peter Hansen,peter,lab_students,peter@example.com
```

- fullname: brugerens fulde navn.
- username: unikt Linux-brugernavn (små ASCII-bogstaver, tal, underscore og bindestreg; starter med bogstav eller underscore).
- group: primær gruppe; skal begynde med lab_ for at begrænse utilsigtet tildeling af systemgrupper.
- email: kontaktinformation, gemmes i GECOS-feltet sammen med navnet.

Scriptet accepterer LF og CRLF samt UTF-8 BOM. Det understøtter ikke citerede CSV-felter, indlejrede kommaer eller linjeskift. Brug komma som separator, ikke semikolon. Eksempelfilen indeholder fiktive oplysninger.

## Anvendelse

Test først uden at ændre systemet:

```bash
./create_users.sh users.example.csv
```

Opret derefter brugerne på din egen testmaskine:

```bash
sudo ./create_users.sh --apply users.example.csv
```

Scriptet validerer hele CSV-filen inden oprettelse, opretter manglende grupper, opretter hjemmemapper under /home og tildeler /bin/bash som shell. Eksisterende brugere springes over. Der tildeles ikke sudo-rettigheder.

## Adgangskoder

Nye konti har låst adgangskode som standard. Adgangskoder gemmes ikke i CSV eller Git. Sæt en midlertidig adgangskode interaktivt og kræv ændring ved første login:

```bash
sudo passwd anna
sudo chage -d 0 anna
```

En låst adgangskode er ikke nødvendigvis en fuldstændig spærring af alle loginmetoder, eksempelvis SSH-nøgler.

## Kontrol

```bash
getent passwd anna
id anna
ls -ld /home/anna
sudo passwd -S anna
```

## Fejlhåndtering og begrænsninger

Ved ugyldig CSV afsluttes scriptet før ændringer. Ved fejl under selve oprettelsen stopper scriptet; tidligere oprettede konti og grupper bevares (ingen automatisk rollback). Eksisterende hjemmemapper genbruges ikke. Kontrollér eksisterende lab_-gruppers rettigheder inden kørsel. Kør kun på en maskine, du administrerer. Gem virkelige CSV-filer uden for det offentlige repository; .gitignore beskytter ikke filer, der allerede er tracked.

## Licens

Copyright 2026 Ib Helmer Niesen. Apache License 2.0. Se [LICENSE](LICENSE).
