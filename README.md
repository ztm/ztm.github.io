# <center>AlarmFirst</center>
### <center>Adatbázis vagyonvédelmi területen távfelügyeleti szolgáltatást nyújtó cégek részére</center>
&nbsp;
## Adatbázis rövid ismertetése
Célja, hogy a cég napi tevékenységét elősegítse. Rögzíti az ügyfelek szerződéses adatait, nyilvántartja a cég személyi-, és eszközállományát, elősegíti a járőrszolgálat tevékenységét.\
\
Az ügyfeleknél elhelyezett kliens adóberendezések riasztás-, hiba-, és állapot jelzéseket küldenek a távfelügyeletre, melyekre a szerződésben meghatározott módon történik intézkedés. Az adóberendezések egyedi sorszámmal (azonosítószám) rendelkeznek és a távfelügyelten üzemelő, más-más jelformátumot fogadni képes vevőberendezésekre (vonalszám) küldik jelzéseiket.\
\
Az ügyfelekre a napi ügymenet során a cégnél a vonal-azonosító párossal hivatkoznak, az adatbázis függvényei, tárolt eljárásai is ebben a formában várják, illetve adják vissza az adatokat. A továbbiakban `azonosítószám` hivatkozásként jelenik meg a dokumentációban.\
Előírás, hogy az ügyféltáblán történt minden adatmódosítás archiválásra kerüljön, ezért a Customer tábla rendelkezik egy logoló táblával (temporal table) is.

## Hardver-, és software követelmény
* Microsoft SQL server v2019 futtatására alkalmas hardware, esetleg virtuális gép.
* Operációs rendszer: Windows 10 vagy Linux, angol nyelvi beállításokkal.
* T-SQL kód futtatására alkalmas IDE, pl. Microsoft SSMS v18 vagy Azure Data Studio v1.41.\
A fejlesztés DBeaver v22 környezetben zajlott.

## SQL server beállítások
* CU19 vagy magasabb frissítés, a fejlesztés során CU19 volt érvényben.
* Az UDF Inline módban történő futtatása miatt javasolt a 150-es compatiblity level használata.
* Az adatbázis FULL recovery modellt használ.
* Az adatbázis a telepítés során átkapcsol Multi-User módba.

## Adatbázis telepítése
A telepítő csomag 3db file-t tartalmaz:
* 01-create_script.sql
* 02-insert_sample_data.sql
* AlarmFirst.bak


Az üres adatbázis telepíthető a [01-create_script.sql](https://github.com/ztm/ztm.github.io/blob/main/01-create_script.sql) futtatásával vagy az `AlarmFirst.bak` file-ból történő visszaállítással.\
Az üres adatbázist a [02-insert_sample_data.sql](https://github.com/ztm/ztm.github.io/blob/main/02-insert_sample_data.sql) futtatásával tölthetjük fel mintaadatokkal.

## Adatbázis ER-diagram
Az adatbázis ER diagramja megtalálható a feltöltött [ssms-er-diagram.pdf](https://github.com/ztm/ztm.github.io/blob/main/ssms-er-diagram.pdf) file-ban. A táblakapcsolatok elemei (Foreign Key - Primary Key párok) a diagramról egyértelműen beazonosíthatók.

## Adatbázis elemei
Az adatbázis a 3NF normál formának megfelelően került kialakításra, az alábbi objektumokat tartalmazza:
* 4 db séma
* 3 db szerepkör a hozzájuk tartozó felhasználókkal
* 15 db tábla, ebből egy logoló tábla
* 5 db nézettábla (view), ebből egy csak megkerülő megoldás függvény használathoz
* 8 db trigger
* 6 db UDF skaláris függvény, ebből kettő CHECK konstraintekben alkalmazott
* 2 db UDF inline táblaértékkel visszatérő függvény
* 10 db tárolt eljárás, ebből egy dedikált hibakezelésre
* Constraint-ek és indexek

## Adatbázis elemek részletesebb ismertetése
## *Táblák*
Constraint szinten a táblák többsége tartalmaz DEFAULT és/vagy CHECK constraint-et. A táblák leírásában az evidenseket nem említem meg külön, a mellékelt [01-create_script.sql](https://github.com/ztm/ztm.github.io/blob/main/01-create_script.sql) file-ban elemezhetők. Kiemelésre csak a megszokottól eltérők kerülnek.\
Általánosságban elmondható, hogy minden táblán a Foreign Key oszlopokon nonclustered index van. Index szinten is csak a különlegesebbek (UNIQUE filtered, spatial) kerülnek említésre.

### *Customer*
Az adatbázis központi eleme, ez tárolja az ügyfelek szerződéses adatait, mint a szerződő neve, címe, számlázási adatai. Érzékeny oszlopai a *cancelCode* és *serviceFee*, ezeket nem minden felhasználó láthatja. A [techRole] csoport tagjai elől a *cancelCode* Dynaic Data Masking-al elrejtésre kerül, a [dispRole] szerepkörhöz tartozó felhasználók pedig SELECT joggal nem rendelkeznek a *serviceFee* oszlopon. Az ügyfelek GPS koordinátáit felvitelkor LAT / LONG formátumban adják meg, a táblában már geográfiai adatként kerül letárolásra (*geoData*).\
Ez a tábla tartalmazza a járőrszolgálat számára lényeges információkat is, pl. adtak le kártyát (*isCard*) / kulcsot (*isKey*) / kapukódot (*isCode*) / távirányítót (*isRemote*) a bejutáshoz, van-e a helyszínen kutya (*isDog*).\
Az *isActive* oszlop az ügyfél státuszát jelzi vissza, 1-es érték esetén a beérkező jelzésekre kell reagálni, 0 esetén az ügyfél státusza felfüggesztett (nem fizetés vagy szolgáltatás szüneteltetése miatt), így intézkedés nem történik.\
Az *isDeleted* oszlop 1-es értéke jelzi, ha az ügyfél törlésre került, mert a szolgáltatást felmondta.

#### Említést érdemlő constraint-ek és index-ek a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|CK_customer_taxnum | Amennyiben cég (*isCompany = 1*) a számlafizető, úgy kötelezően kitöltendő elem az adószám (*invoiceTaxNumber*). Egyéb esetben lehet NULL. Egyediségét nem vizsgáljuk, gyakran előforduló eset, hogy az előfizető több bekötéssel is rendelkezik, ugyanazokkal a számlázási adatokkal. |
|CK_customer_category | Az objektumnak a fixen rögzített kategóriák valamelyikébe kell esnie, melyek: *'small office'*, *'supermarket'*, *'family house'*, *'storage'*, *'apartment'*, *'office building'* lehetnek. |
|CK_customer_installertech | A technikus ID-t ellenőrző constraint. Telepítést és javítást csak technikus végezhet, a megfelelő ID-ról a constraint-ben alkalmazott *office.chkTech()* függvény gondoskodik. Az *installerID* egy esetben vehet fel NULL értéket, ha az utolsó technikus is elmegy a cégtől. |
|CK_customer_state | Előfizető megfelelő állapotát biztosító constraint. Törölt ügyfél esetén az *isActive* csak 0 értéket vehet fel. |
| **Index neve** | **Leírása** |
|idx_customer_deviceID | UNIQUE filtered index a *deviceID* oszlopon. *isDeleted* = 0 esetén biztosítja, hogy egy készülék csak egy ügyfélhez kerülhessen fel. |
|idx_customer_geo | spatial index a *geoData* oszlopon |

&nbsp;
### *CustomerArchive*
Logoló tábla, a Customer tábla adataiban bekövetkező minden változást ebben tárolunk.

&nbsp;
### *CustomerContact*
A Customer táblához kapcsolódik, a riasztás esetén értesítendő személyek listáját tárolja elérhetőségeikkel együtt. Az értesítendők között prioritási sorrend van (*priority*), akit elsőnek elérnek a diszpécserek ott megszakad a lánc. A *note* oszlopban lehet az értesítendőhöz tartozó megjegyzéseket rögzíteni, pl. "csak hétvégén elérhető".

#### Említést érdemlő constraint a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|UK_customercontact_priority | UNIQUE composit key a *customerID* és *priority* oszlopokon együttesen. Biztosítja, hogy adott előfizető esetén a prioritási sorrend egyedi legyen, ne vehessen fel azonos értéket. |

&nbsp;
### *CustomerSignalType*
Szintén a Customer táblához kapcsolódik, a kliens oldalról beérkező jelzéseket (*zoneNumber*) tárolja. Minden jelzéshez rendelünk egy általános kódot (*code*), betörés típusú jelzések esetén ez "BTS", támadás típusú jelzés esetén "TMJ", stb. A *description* oszlop tartalmaz bővebb információt a jelzés helyéről, pl. "Nappali mozgásérzékelő".\
Ebben a táblában kerül meghatározásra, hogy az adott jelzésre járőrt kell küldeni vagy elég csak felhívni az ügyfelet (*isPatrol*). Általánosságban elmondható, hogy a riasztás típusú (pl. betörés, szabotázs) jelzésekre kell járőr küldéssel reagálni, míg a technikai jelzések (pl. hálózatkimaradás, akkumulátor hiba) esetén csak hívni kell az ügyfelet.\
Az *isPatrol* NULL értéket is felvehet, ebben az esetben a beérkezett jelzés nem kíván semmilyen intézkedést. Ilyen lehet pl. a rendszer Élesített / Hatástalanított állapotát tükröző, csak egyéb információt hordozó jel.

#### Említést érdemlő constraint a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|UK_customersignaltype_zone | UNIQUE composit key a *customerID* és *zoneNumber* oszlopokon együttesen. Ugyanattól az ügyféltől csak eltérő zónainformációk (események) érkezzenek be. |

&nbsp;
### *Invoice és Payment*
Az Invoice az ügyfél részére kiállított számlákat, a Payment az ügyfél által eszközölt befizetéseket tartalmazza. Számla "törlése" esetén az *Invoice* táblában csak az *isDeleted* bit kerül beállításra, a negatív sztornó számla elkészítéséről egy trigger gondoskodik.\
A *Payment* tábla *status* oszlopa hivatott jelezni, ha nem a megfelelő összeg került befizetésre. Az állapot aktualizálását az *office.trgPaySatatusUp* és *office.trgPaySatatusDel* triggerek automatikusan elvégzik. NULL esetén a számlán szereplő összeget fizették be, 0 esetén az ügyfélnek tartozása, 1 esetén túlfizetése van. Amennyiben a számlát több részletben fizetik be, a trigger az összes befizetés *status*-át a megfelelő értéken tartja.

#### Említést érdemlő constraint az Invoice táblán
|Constraint neve | Leírása |
|:--- | :--- |
|UK_invoice_invoiceNumber | UNIQUE key az *Invoice* tábla *invoiceNumber* oszlopán a számlaszám egyediségének kikényszerítésére. |

&nbsp;
### *SubscriptionType*
Az igénybe vehető szolgáltatások listáját tartalmazza. Ez lehet kedvezményes vagy teljes árú (*isDiscount*), és megadjuk, hogy az adott  csomag mely időpontok - *validFrom* és *validUntil* - között érhető el.

&nbsp;
### *Device*
Kliens oldali eszköz jellemzőit tartalmazó tábla. Az eszköz egyedi, beprogramozott azonosítóval rendelkezik (*deviceNumber*) és logikai hozzárendelés eredménye lesz a vevő (*lineNumber*), mely az eszközről érkező, különböző formátumú jelzéseket fogadja. A kettő együtt biztosítja a felszerelt eszköz egyediségét.\
Szintén a tábla tárolja GPRS készülék esetén az eszközbe helyezett SIM kártyák (*firstSIM* és *secondSIM*) sorszámát, az eszköz *IMEI* azonosítóját és egyedi sorozatszámát (*serial*).

#### Említést érdemlő constraint-ek és index-ek a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|CK_device_simX | A constraint-ben alkalmazott *tech.chkSIM()* függvény feladata biztosítani, hogy már kiadott kártya ne kerülhessen ismételten kiadásra, illetve, hogy a GPRS készülékekbe csak adat-forgalomra szánt kártya kerüljön. |
| **Index neve** | **Leírása** |
|idx_device_serial | UNIQUE filtered index a *serial* oszlopon. A GPRS protokollt használó készülékek egyedi sorozatszámmal rendelkeznek, előírás, hogy ezeket rögzíteni kell. Más protokollok esetén az érték lehet NULL. |

&nbsp;
### *DeviceType*
A Device táblában letárolt eszközök műszaki paramétereit tartalmazó tábla. Itt jelenik meg a vonalszám vevőjének azonosítója (*receiver*), illetve az egyes protokollokhoz (*protocol*) tartozó "Életjel" küldés gyakorisága (*lifeTimeCycle*), ennek a kódja (*TSTcode*), illetve az ennek hiányában keletkező, generált jelzés kódja (*TSTfailedCode*).

&nbsp;
### *Staff*
A cég személyzeti állományát és jellemzőiket (*staffName* - az alkalmazott neve, *Salary* - az alkalmazott bruttó bére, *dateHired* - munkába állás időpontja) tartalmazó tábla.\
Szervizesek esetén kötelező elem a tevékenység végzéséhez szükséges igazolvány számának megadása (*passNumber*).\
Itt kerül rögzítésre, hogy az illető mely munkakörben dolgozik, *isTech* - *isOffice* - *isPatrol* - *isDispatcher* oszlopok, illetve, hogy mely körzetben (*workplaceID*) látja el feladatát.\
A *carID* és *SIMid* oszlopok az alkalmazott által használt gépjárművet és mobilt rögzítik (ha van ilyen).\
A *terminationDate* oszlop a munkaviszony megszűnésének időpontja, ezt az *office.trgEmployeeQuit* trigger állatja be az alkalmazott törlése esetén.

#### Említést érdemlő constraint-ek és index-ek a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|CK_staff_passNumber | Technikus esetén az igazolvány számának (*passNumber*) egyediségét kikényszerítő szabály. |
|CK_staff_sim3 | Hasonlóan a *Device* táblához, a *tech.chkSIM()* függvény feladata biztosítani, hogy már kiadott kártya ne kerülhessen ismételten kiadásra, illetve, hogy a személyzet által használt mobilba hanghívásra is alkalmas kártya kerüljön. |
|CK_staff_active | Biztosítja, hogy a dolgozó nem lehet egyszerre aktív és törölt állapotban is. |
|CK_staff_quit | Biztosítja, hogy kilépéskor a távozó nevén ne maradjon gépjármű és telefon (SIM). |
|CK_staff_department | A constraint gondoskodik róla, hogy egy alkalmazott csak egy részleghez tartozhat. |
| **Index neve** | **Leírása** |
|idx_staff_pass | UNIQUE filtered index a *passNumber* oszlopon. A technikusok igazolványszáma nem lehet azonos. |

&nbsp;
### *Workplace*
Azon körzetek listája, melyekben a cég tevékenységet végez. Amennyiben egy városban több kerületben is jelen van, úgy a *district* oszlop ad tájékoztatást a kerületről.

&nbsp;
### *Car*
A cég tulajdonában álló gépjárművek listája, azok minden szükséges jellemzőjével (*licensePlate* - rendszám, *make* / *model* / *productionYear* - a gépjármű típusa és gyártási éve).\
A tábla segítségével lekérhető, hogy az autó mikor volt utoljára műszaki vizsgán (*lastInspectionDate*), hol áll a KM-óra (*coveredDistance*), mikor esedékes a következő kötelező szerviz (*nextMOTTestKM*).\
Ugyancsak itt kerül letárolásra a jármű pozícióját megadó, a beépített GPS jeladóról érkező jelzés geográfiai adat formájában (*carGeoData*).

#### Említést érdemlő index a táblán
| Index neve | Leírása |
|:---|:---|
|idx_patrol_cargeo | spatial index a *carGeoData* oszlopon |

&nbsp;
### *SIM*
A cég által használt SIM kártyák listája. Letároljuk a kártya hívószámát (*phoneNumber*), a SIM egyedi azonosítóját (*SIMnumber*).\
A kártya elsődleges felhasználási területe a kliens oldali GPRS készülékekbe helyezett adat SIM kártya, ezt az *isData* oszlopban megkülönböztetjük az alkalmazott mobiljába kerülő, hanghívásra is alkalmas SIM-ektől.\
Amennyiben a kártya kiadásra került, úgy az *isIssued* oszlop 1 értéke ezt jelzi, illetve a *dateIssued* oszlop ad tájékoztatást a kiadás időpontjáról. Visszavonás esetén az *isIssued* 0-t, míg a *dateIssued* NULL értéket vesz fel. Mindkettőt a megfelelő triggerek automatikusan állítják be.

#### Említést érdemlő constraint-ek a táblán
|Constraint neve | Leírása |
|:--- | :--- |
|UK_sim_SIMnumber | SIM kártya számának egyediségét kikényszerítő szabály. |
|UK_sim_phoneNumber | A telefonszám egyediségét kikényszerítő szabály. |

&nbsp;
### *Patrol*
A járőrök szolgálati beosztását tartalmazó tábla, megjelölve a szolgálati idő kezdetét és végét, *dutyStart* és *dutyEnd* oszlopok. Megjelenik, hogy az adott járőr fegyveres szolgálatot lát el vagy sem (*isArmed*) és itt kerül rögzítésre, hogy épp úton van egy riasztás helyszínére vagy riasztás esetén küldhető (*isOnCase*).

#### Említést érdemlő index-ek a táblán
| Index neve | Leírása |
|:--- |:---|
|idx_patrol_dutystart | Mivel mindig az időben legfrissebb eseményekre keresünk, ezért az index csökkenő sorrendben tárolja a *dutyStart* oszlop értékeit. |
|idx_patrol_dutyend | Hasonló okokból az előzőhöz, itt is csökkenő sorrendben indexelünk a *dutyEnd* oszlopon. |

&nbsp;
### *ReceivedSignal*
Ügyféloldali készülékről beérkező jelzések táblája. A jelzés során megjelenik az ügyfél azonosítója (*customerID*), a jelzés beérkezésének időpontja (*timeReceived*) és hogy milyen esemény váltotta ki a jelzést (*zoneNumber*). A jelzés lehet technikai jellegű is (pl. hálózathiba), mely nem kíván kivonulást csak értesítést.\
Riasztásjelzés esetén bekerül a kiküldött járőr azonosítója (*patrolID*) és indításának, valamint a helyszínre érkezésének időpontja is (*timePatrolStart* és *timePatrolOnSpot* oszlopok).\
Rögzítésre kerül minden esetben az intézkedő diszpécser azonosítója (*dispatcherID*).

&nbsp;
## Nézettáblák (view)
### *tech.vCustomerBaseData*
Ügyfél alapadatok megjelenítése technikus számára kapcsolatfelvételi (pl. időpont egyeztetése javítás elvégzésére) célzattal.
A nézet tartalmazza az ügyfél azonosítószámát, nevét, címét, elérhetőségeit, a kihelyezett berendezésről beérkező jelzéseket, melyek a technikus számára nyújtanak kezdeti információt a hibáról.

### *patrol.vAlarm*
Célja, hogy beérkező riasztás esetén elegendő információt szolgáltasson a diszpécser számára az eseményről és a kívánt intézkedésről.\
Látja, hogy a beérkezett jelzésre milyen intézkedést kell foganatosítania (csak hívni az ügyfelet vagy egyből indítani a járőrt), megjelenik előtte a riasztás esetén értesítendő személyek listája a megadott prioritással.\
Látja az objektum GPS-koordinátáit, az objektum egyéb jellemzőit, pl. van-e kutya a helyszínen, adtak-e le kulcsot / kártyát / kódot a bejutáshoz, vannak-e az objektumnak olyan egyéb jellemzői (pl. nehéz megközelíthetőség) amit a járőrnek továbbadva a sikeres intézkedést elősegítheti.

### *tech.vTechnical*
Technikusok számára ad a kliens oldali eszköz paramétereiről információt. Megkapja az eszköz azonosítószámát, milyen típusú jelátvitelt használ az eszköz, ha van benne SIM kártya, annak mi a hívószáma (távprogramozás, újraindítás lehetősége).

### *office.vAccount*
Könyveléshez készült nézet, az ügyfél részére kiállított számlákat és az eszközölt befizetéseket tartalmazza.\
Megjelenik benne a formázott számlaszám, a fizető neve és címe, a kiszámlázott tétel összege, darabszáma, ÁFA-tartalma, a számla végösszege, a számla kelte és a teljesítés időpontja is.\
Megjelenik továbbá a befizetett összeg, a befizetés időpontja, a befizetés állapota.\
Tartalmazza a nézet, hogy a távfelügyeleti szolgáltatást aktívan igénybe vevő ügyfélről van szó vagy sem. (Fenntartási díjat a kihelyezett készülék után a nem aktív státuszban levő felhasználók is fizetnek, illetve időszakos karbantartásra, eseti javításokra ők is igényt tarthatnak.)

&nbsp;
## *Függvények*
### *office.chkTech()* skaláris UDF
CHECK constraint-ben alkalmazott UDF, kétféle visszatérési értéke lehetséges: 1 és -1.\
Amennyiben technikusról van szó, 1-et, egyéb esetekben vagy ha nincs már technikus, -1-et ad vissza.\
**Bemeneti paramétere:**\
&ensp;&ndash; *installerID:* az ellenőrzendő alkalmazott ID-ja

### *tech.chkSIM()* skaláris UDF
CHECK constraint-ben alkalmazott UDF, kétféle visszatérési értéke lehetséges: 1 és -1.\
Megvizsgálja, hogy a paraméterként kapott SIM egyáltalán létezik vagy sem, ha létezik, akkor használatban van vagy sem, ha nincs használatban akkor pedig megfelel a paraméterként megkapott típusnak vagy sem.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *simID:* az ellenőrzendő SIM ID-ja\
&ensp;&ndash; *type:* az ellenőrzendő SIM típusa. 0 = hang, 1 = adat.

### *office.findCustomer()* skaláris UDF
Kódismétlés elkerülése végett létrehozott függvény. Tárolt eljárásokban gyakran előforduló lekérdezés, hogy a vonalszám-azonosítószám pároshoz tartozó *customerID*-t változóban eltároljuk.\
A függvény a *customerID* értékét adja vissza.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *lineNumber:* az ellenőrzendő vonalszám\
&ensp;&ndash; *deviceNumber:* az ellenőrzendő eszközszám

### *tech.randomInst()* skaláris UDF
Triggerben használt függvény, távozó technikus esetén a megmaradt technikusok közül véletlenszerűen kiválaszt egyet és azt adja visszatérési értékként.\
Az érték a *Customer* tábla *installerID* oszlopába kerül az UPDATE után.\
Bemeneti paramétere nincs.

### *office.customerBalance()* skaláris UDF
Ügyvitelhez készült skaláris függvény, mely adott időszakra vonatkozóan adja vissza az ügyfél egyenlegét.\
Bemeneti paraméterként megkapja az ügyfél azonosítószámát - vonalszám és eszköz azonosító formában -, valamint a kezdő és végző dátumot.\
Visszatérési értékként az egyenleget kapjuk meg pénznemre formázott változatban.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *lineNumber:* az eszköz vonalszáma\
&ensp;&ndash; *deviceNumber:* az eszköz egyedi sorozatszáma\
&ensp;&ndash; *startDate:* az egyenleg lekérdezés kezdő időpontja\
&ensp;&ndash; *endDate:* az egyenleg lekérdezés végződő időpontja. Ha nem adjuk meg (DEFAULT), akkor a függvény automatikusan az aktuális dátumra állítja be.

### *office.customerDue()* iTVF
Tartozással rendelkező ügyfelek listája adott időszakra vetítve.\
A függvény bemenetként csak a kezdő és végző dátumot várja, ezután tábla formában megkapjuk a tartozással rendelkező ügyfelek listáját. Amennyiben nem adunk meg végző dátumot, azt a függvény az aktuális dátumra állítja be. A lista tartalmazza az ügyfél azonosítószámát, nevét és címét valamint a tartozás összegét.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *startDate:* az egyenleg lekérdezés kezdő időpontja\
&ensp;&ndash; *endDate:* az egyenleg lekérdezés végződő időpontja

### *patrol.findNextXPatrol()* iTVF
Ezzel a függvénnyel a diszpécserek munkáját kívánjuk segíteni. Beérkező riasztás esetén visszaadja a helyszínhez legközelebb levő szabad járőröket. A függvény bemeneti paramétereként megadhatjuk az elérni kívánt járőrök számát. Alapértelmezett értéke 1, mellyel csak a helyszínhez legközelebbi járőrt kapjuk vissza.
A függvény a ReceivedSignal táblából automatikusan választja ki azon utolsó eseményt, amelyre járőr kiküldésével kell reagálni.\
Az ügyféladatok felvitele során kötelező elem a helyszín GPS LAT / LONG koordináta párosa, ezeket geográfiai adat formában tárolja az adatbázis. Ugyanígy tárolja le a gépjárművekbe szerelt GPS jeladóktól percenkénti frissítéssel beérkező GPS koordinátákat is. A kettő különbsége alapján kerül megállapításra a küldendő járőr, az ő adatai jelennek meg a diszpécserszolgálat számára.\
**Bemeneti paramétere:**\
&ensp;&ndash; *pCount:* a helyszínhez legközelebb tartózkodó *N* járőr száma

&nbsp;
## Triggerek
A triggerek közül az *office.trgInvoiceDel* számla törlés esetén a negatív számla elkészítésért felel, illetve a törlendő számla *isDeleted* bit-jét állítja át. Maga a számla nem kerül törlésre.\
\
Az *office.trgPayStatusUp* és *office.trgPayStatusDel* gondoskodik a befizetések *status* attribútumának megfelelő állapotáról. Amennyiben a befizetett összeg egyezik a számlán szereplő összeggel, úgy értéke NULL. Tartozás esetén az oszlop 0, míg túlfizetés esetén 1 értéket vesz fel.\
\
A többi trigger az eszközökben (*Device*) és a személyzetben (*Staff*) beálló változásokat követi le és állítja be az INSERT / UPDATE / DELETE utáni állapotnak megfelelő attribútumokat.\
Pl. a *Customer* táblában technikus távozása esetén a hozzá tartozott ügyfélkört (*installerID*) véletlenszerűen elosztja a megmaradt technikusok közt.\
\
A *trgInvoiceDel*, *trgPayStatusUp*, *trgPayStatusDel* kivételével a triggerek fő feladata a *SIM* tábla aktualizálása. A *SIM* táblába az [officeRole] körbe tartozó felhasználónak sincs UPDATE joga, ezt a triggerek automatikusan elvégzik. Oda kizárólag beszúrni (új SIM vásárlása) vagy törölni (SIM elveszett / megsérült) lehet. Törölni a kártyát az egyéb hivatkozások (*Device* és *Staff* táblák) megszüntetése után lehetséges.

&nbsp;
## *Tárolt eljárások*
A tárolt eljárások mindegyike tartalmaz hibakezelést (TRY / CATCH), a hiba lekezelése a dedikált *dbadmin.error_handler* eljáráson keresztül történik meg.
### *dbadmin.error_handler*
Célja, hogy a tárolt eljárásokban, triggerekben bekövetkező hibák esetén egységes visszajelzést valósítson meg. Felhasználói és/vagy rendszer hibaüzeneteket ad vissza formázott állapotban. A megjelenített hiba a hibaüzeneten felül tartalmazza többek között a tárolt eljárás megnevezését (*ERROR in proc*), hogy a tárolt eljáráson belül a kód mely részén történ a hiba (*Error State*), mely felhasználónál jött elő a hiba (*User*).\
**Bemeneti paraméterek:**\
&ensp;&ndash; *errMsg:* a feldolgozandó hibaüzenet\
&ensp;&ndash; *errState:* a kód mely részén történt a hiba


### *office.custBalance*
A korábban már bemutatott *office.customerBalance* függvény praktikusabb felhasználását teszi lehetővé. Segítségével megállapítható, hogy a kérdéses felhasználó létezik vagy sem, illetve az egyenleget már formázott állapotban kapjuk vissza.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *lineNumber:* az eszköz vonalszáma\
&ensp;&ndash; *deviceNumber:* az eszköz egyedi sorozatszáma\
&ensp;&ndash; *startDate:* az egyenleg lekérdezés kezdő időpontja\
&ensp;&ndash; *endDate:* az egyenleg lekérdezés végző dátuma


### *office.addCustomer*
A benne foglalt hibakezelés (SIM feltétel ellenőrzés) miatt kizárólag ezzel a tárolt eljárással lehet új ügyfelet felvinni az adatbázisba. A tábla oszlopain kívül rögzítés során megadható az eszközbe került SIM kártyák azonosítója is. A GPS koordinátákat a megszokott LAT / LONG formátumban kell megadni, az eljárás gondoskodik arról, hogy a táblába ez már geográfiai adatként kerüljön be.\
**Bemeneti paraméterek:**\
**Kötelező megadni (nem GPRS készülék):**\
&ensp;&ndash; lineNumber - vonalszám\
&ensp;&ndash; deviceNumber - eszköz azonosító\
&ensp;&ndash; cancelCode - lemondó kód\
&ensp;&ndash; customerName - ügyfél neve\
&ensp;&ndash; customerCity - város megnevezése\
&ensp;&ndash; customerAddress - ügyfél címe\
&ensp;&ndash; customerZIP - irányítószám\
&ensp;&ndash; customerLONG - a hely GPS koordinátája\
&ensp;&ndash; customerLAT - a hely GPS koordinátája\
&ensp;&ndash; customerPhone - ügyfél telefonszáma\
&ensp;&ndash; serviceFee - szolgáltatási díj, nettó\
&ensp;&ndash; category - kategória megnevezése\
&ensp;&ndash; subscriptionID - előfizetés azonosítója\
&ensp;&ndash; installerID - technikus azonosítója\
\
**Kötelező megadni (GPRS készülék):**\
A fentieken kívül GPRS készülék esetén legalább egy SIM kártya megadása kötelező.\
&ensp;&ndash; firstSIM - SIM azonosítója\
\
**Opcionális paraméterek:**\
&ensp;&ndash; secondSIM - GPRS készülék második SIM kártyája\
&ensp;&ndash; customerEmail - előfizető mail címe\
&ensp;&ndash; invoiceName - számlázási név\
&ensp;&ndash; invoiceCity - számlázás város megnevezése\
&ensp;&ndash; invoiceAddress - számlázási cím\
&ensp;&ndash; invoiceZIP - számlázás irányítószáma\
&ensp;&ndash; isCompany - 0 = magánszemély, 1 = cég\
&ensp;&ndash; invoiceTaxNumber - adószám, cég esetén kötelező\
&ensp;&ndash; contractDate - szerződés dátuma\
&ensp;&ndash; note - egyéb megjegyzés\
&ensp;&ndash; isDog - kutya van / nincs\
&ensp;&ndash; isKey - kulcsot leadtak vagy sem\
&ensp;&ndash; isCard - beléptető kártyát leadtak vagy sem\
&ensp;&ndash; isCode - kapukódot megadtak vagy sem\
&ensp;&ndash; isRemote - távirányítót leadtak vagy sem\
&ensp;&ndash; isGuard - az objektum őrzött vagy sem\
&ensp;&ndash; isSprinkler - automata oltórendszer van / nincs\
\
Amennyiben számlázási adatokat nem adunk meg, úgy automatikusan az előfizető nevére és címére állítja be az eljárás.\
Ha a *contractDate* elmarad, az eljárás az aktuális dátumra állítja be.\
Az *isActive* és a *patrolCount* oszlopok értékei automatikusan kerülnek alapértelmezett értékre.\
Az *isDeleted* oszlopnak ebben az esetben nincs létjogosultsága.


### *office.modCustomer*
Meglevő ügyfél adatainak módosítására kizárólagosan használható tárolt eljárás. Vizsgálja, hogy létező ügyfélről van szó vagy sem, illetve címváltozás esetén itt is a LAT / LONG koordináta páros megadása az elvárt.\
**Bemeneti paraméterek:**\
**Kötelező megadni:**\
&ensp;&ndash; lineNumber - vonalszám\
&ensp;&ndash; deviceNumber - eszköz azonosító\
\
**Opcionális paraméterek:**\
&ensp;&ndash; a *Customer* tábla szinte összes oszlopa.\
A modulban állítható át az előfizető *isActive* státusza, amennyiben pl. a szolgáltatás szüneteltetését kéri.\
Az *isDeleted*-nek ebben az esetben sincs létjogosultsága.


### *office.delCustomer*
Ügyfél törlésre kizárólagosan használható tárolt eljárás. Az eljárás törlés előtt vizsgálja az ügyfél számlaegyenlegét, törölni csak nullás egyenleggel rendelkező ügyfelet lehet. Az eljárás gondoskodik a törlendő ügyfélhez kötődő kapcsolatok (*CustomerContact*, *CustomerSignalType*) megszüntetéséről is, illetve törlésre kerül az ügyféltől leszerelt eszköz azonosítója (*deviceID*) is. Amennyiben az eszköz használt SIM kártyát, úgy ezeket újra felhasználhatóvá teszi a *SIM* és *Device* tábla megfelelő oszlopainak aktualizálásával.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *lineNumber:* az eszköz vonalszáma\
&ensp;&ndash; *deviceNumber:* az eszköz egyedi sorozatszáma


### *office.addInvoice*
Számlázási adatok felvitelére szolgáló tárolt eljárás. A számla folyamatosan, kihagyások nélkül növekvő sorszámozását SEQUENCE biztosítja. Hiba esetén a CATCH ágban lefutó Dynamic SQL kód gondoskodik a SEQUENCE megfelelő visszaállításáról.\
**Bemeneti paraméterek:**\
**Kötelező megadni:**\
&ensp;&ndash; *lineNumber:* az eszköz vonalszáma\
&ensp;&ndash; *deviceNumber:* az eszköz egyedi sorozatszáma\
&ensp;&ndash; *unitDescription:* értékesített szolgáltatás megnevezése\
&ensp;&ndash; *unitPrice:* értékesített szolgáltatás nettó egységára\
&ensp;&ndash; *quantity:* értékesített szolgáltatás mennyisége\
&ensp;&ndash; *description:* egyéb megjegyzés\
&ensp;&ndash; *isViaMail:* számla papírformátumú legyen vagy e-mail-ben kiküldött\
\
**Opcionális paraméterek:**\
&ensp;&ndash; *invoiceDate:* a számla keltezésének napja\
&ensp;&ndash; *invoiceDueDate:* a számla fizetési határideje\
Amennyiben nem adjuk meg az *invoiceDate* és *invoiceDueDate* paramétereket, úgy a modul az *invoiceDate*-et az aktuális dátumra, az *invoiceDueDate* értékét az aktuális dátum + 10 napra állítja be.


### *office.delInvoice*
Hibásan felvitt számlázási adatok "törlésre" szolgáló tárolt eljárás. Mivel a számvitelei szabályok értelmében számlát törölni nem szabad, így a korábban már említett *office.trgInvoiceDel* trigger gondoskodik a számla *isDeleted* bit-jének átállításáról és a sztornó számla elkészítéséről.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *lineNumber:* az eszköz vonalszáma\
&ensp;&ndash; *deviceNumber:* az eszköz egyedi sorozatszáma\
&ensp;&ndash; *invoiceNumber:* a törlendő számla sorszáma


### *office.addStaffMember*
Alkalmazott felvitelét elősegítő tárolt eljárás. A hibakezelés miatt javasolt a használata, egyébként új alkalmazottat az INSERT statement-el is hozzáadhatunk az adatbázishoz. Az érvényes adatok beviteléről a CHECK constraint-ek gondoskodnak.\
**Bemeneti paraméterek:**\
**Kötelező megadni (nem technikus esetén):**\
&ensp;&ndash; *staffName:* az alkalmazott neve\
&ensp;&ndash; *salary:* az alkalmazott bruttó bére\
&ensp;&ndash; *isTech:* technikusi munkakörbe kerül\
&ensp;&ndash; *isOffice:* irodai munkakörbe kerül\
&ensp;&ndash; *isPatrol:* járőri munkakörbe kerül\
&ensp;&ndash; *isDispatcher:* diszpécser munkakörbe kerül\
&ensp;&ndash; *workplaceID:* a kirendeltség, melyben az alkalmazott ellátja feladatát\
Az *isTech* - *isOffice* - *isPatrol* - *isDispatcher* oszlopok közül csak az egyiket kell megadni, függően attól, hogy az alkalmazott mely munkakörbe nyert felvételt.\
\
**Kötelező megadni (technikus esetén):**\
A fentieken kívül technikus esetében kötelező elem a tevékenység végzéséhez szükséges igazolvány számának rögzítése is.\
&ensp;&ndash; *passNumber:*  vagyonvédelmi igazolvány száma\
\
**Opcionális paraméterek:**\
&ensp;&ndash; *dateHired:* munkába állás időpontja\
&ensp;&ndash; *carID:* ha kap autót, a gépjármű azonosítója\
&ensp;&ndash; *SIMid:* ha kap telefont, a SIM kártya azonosítója\
Amennyiben a *dateHired* nem kerül megadásra, a program automatikusan az aktuális dátumot rögzíti.


### *office.modStaffMember*
Alkalmazott adataiban bekövetkező változás rögzítését elősegítő tárolt eljárás. A hibakezelés miatt javasolt a használata, egyébként az alkalmazott adatait az UPDATE statement-el is módosíthatjuk. Az érvényes adatok beviteléről itt is a CHECK constraint-ek gondoskodnak.\
**Bemeneti paraméterek:**\
**Kötelező megadni:**\
&ensp;&ndash; *staffid:* a módosítandó alkalmazott ID-ja\
\
**Opcionális paraméterek:**\
&ensp;&ndash; *staffName:* az alkalmazott neve\
&ensp;&ndash; *passNumber:*  vagyonvédelmi igazolvány száma\
&ensp;&ndash; *salary:* az alkalmazott bruttó bére\
&ensp;&ndash; *isTech:* technikusi munkakörbe kerül\
&ensp;&ndash; *isOffice:* irodai munkakörbe kerül\
&ensp;&ndash; *isPatrol:* járőri munkakörbe kerül\
&ensp;&ndash; *isDispatcher:* diszpécser munkakörbe kerül\
&ensp;&ndash; *workplaceID:* a kirendeltség, melyben az alkalmazott ellátja feladatát\
&ensp;&ndash; *carID:* ha kap autót, a gépjármű azonosítója\
&ensp;&ndash; *SIMid:* ha kap telefont, a SIM kártya azonosítója\
Az *isTech* - *isOffice* - *isPatrol* - *isDispatcher* oszlopok közül csak az egyiket kell megadni, ha esetleg az alkalmazott cégen belül más részleghez kerül.


### *office.delStaffMember*
Alkalmazott kiléptetését (törlését) elősegítő tárolt eljárás. A hibakezelés miatt javasolt a használata, egyébként az alkalmazott a DELETE statement-el is törölhető. A rekord nem kerül törlésre a táblából, aktiválódik az *office.trgEmployeeQuit* trigger és az *isActive* 0-ra állítása jelzi, hogy munkaviszonya megszűnt. A trigger egyben megszünteti a részleghez és kirendeltséghez tartozást, technikus esetén törli a személyes adatnak számító *passNumber* oszlop adatát.\
**Bemeneti paraméterek:**\
&ensp;&ndash; *staffid:* az alkalmazott ID-ja


&nbsp;
## *Sémák, szerepkörök, felhasználók*
* Az adatbázis négy sémára oszlik: [office], [tech], [patrol] és [dbadmin].
* Három szerepkör található az adatbázisban: [officeRole], [techRole] és [dispRole] a hozzájuk rendelt  felhasználókkal.
* Jogosultságok csak szerepkörök vonatkozásában kerültek kiosztásra, felhasználói szinten nem.
  
|Role				|User				|
|:---------	|:----------|
|dispRole		|dispatchers|
|officeRole	|officestaff|
|techRole		|technicians|
  
A szerepkörök (felhasználók) jogosultságait az alábbi táblázatok tartalmazzák. Ezekből leolvasható, hogy adott felhasználó rendelkezik a táblán, nézeten, iTVF-en a művelet elvégzéséhez szükséges jogosultsággal vagy sem. Magasabb szintű jogosultsággal (ALTER) az [officeRole] szerepkör  rendelkezik kizárólag az *Invoice* táblán alkalmazott SEQUENCE vonatkozásában.\
\
Az első táblázat a függvények, tárolt eljárások futtatásához szükséges EXECUTE jogokat mutatja be.\
A rendszer adminisztrátor számára fenntartott [dbadmin] sémához egyik szerepkörnek sincs hozzáférése. A [dbadmin] sémában a rendszer adminisztrátor által használt tárolt eljárások, nézetek találhatók, esetünkben ez az error_handler eljárásra korlátozódik.


**Jelmagyarázat:**\
:heavy_check_mark: - a felhasználó jogosult az adott művelet elvégzésére (GRANT)\
:x: - a felhasználó nem jogosult az adott művelet elvégzésére (DENY)\
:heavy_check_mark: :x: - a felhasználó a táblán korlátozottan képes az adott művelet elvégzésére\
&mdash; - a művelet a táblán nem értelmezhető\
*f* - skaláris függvény\
*p* - tárolt eljárás\
&nbsp;

|EXECUTE |techRole |officeRole |dispRole |
|:---|:---:|:---:|:---:|
|*f:* tech.chkSIM() | :heavy_check_mark: | :heavy_check_mark: | :x: |
|*f:* tech.phoneFormat() | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: |
|*f:* tech.randomInst() | :heavy_check_mark: | :heavy_check_mark: | :x: |
|*f:* office.chkTech()	| :x: | :heavy_check_mark: | :x: |
|*f:* office.customerBalance() | :heavy_check_mark: | :heavy_check_mark: | :x: |
|*f:* office.findCustomer() | :x: | :heavy_check_mark: | :x: |
|*p:* office.custBalance() | :heavy_check_mark: | :heavy_check_mark: | :x: |
|*p:* office.addCustomer() | :x: | :heavy_check_mark: | :x: |
|*p:* office.modCustomer() | :x: | :heavy_check_mark: | :x: |
|*p:* office.delCustomer() | :x: | :heavy_check_mark: | :x: |
|*p:* office.addInvoice() | :x: | :heavy_check_mark: | :x: |
|*p:* office.delInvoice() | :x: | :heavy_check_mark: | :x: |
|*p:* office.addStaffMember() | :x: | :heavy_check_mark: | :x: |
|*p:* office.modStaffMember() | :x: | :heavy_check_mark: | :x: |
|*p:* office.delStaffMember() | :x: | :heavy_check_mark: | :x: |


Megjegyzés: bár a függvények - az *office.customerBalance()* kivételével - CHECK constraint-ekben, tárolt eljárásokban használatosak, lehetőség van azokat önmagukban is futtatni. Gyakorlati haszna igazán nincs, a visszatérési érték ismeretében gyors ellenőrzésre alkalmazhatók.


&nbsp;
|techRole |SELECT |INSERT |UPDATE |DELETE |UNMASK |
|:---|:---:|:---:|:---:|:---:|:---:|
|tech.Device | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|tech.DeviceType | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|tech.CustomerSignalType | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|tech.vCustomerBaseData | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|tech.vTechnical | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.Customer | :heavy_check_mark: | :x: | :x: | :x: | :x: |
|office.CustomerArchive | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | :x: |
|office.CustomerContact | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|office.SubscriptionType | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|office.Invoice | :x: | :x: | :x: | :x: | &mdash; |
|office.Payment | :x: | :x: | :x: | :x: | &mdash; |
|office.Staff | :x: | :x: | :x: | :x: | &mdash; |
|office.Workplace | :x: | :x: | :x: | :x: | &mdash; |
|office.SIM | :x: | :x: | :x: | :x: | &mdash; |
|office.vAccount | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.customerDue iTVF | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.Patrol | :x: | :x: | :x: | :x: | &mdash; |
|patrol.Car | :x: | :x: | :x: | :x: | &mdash; |
|patrol.ReceivedSignal | :heavy_check_mark: :x: | :x: | :x: | :x: | &mdash; |
|patrol.vAlarm | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.findNextXPatrol iTVF | :x: | &mdash; | &mdash; | &mdash; | &mdash; |


Megjegyzés: A patrol.ReceivedSignal táblán a [techRole] szerepkörbe tartozó felhasználók csak a *customerID*, *zoneNumber* és *timeReceived* oszlopokon rendelkeznek SELECT joggal, a *dispatcherID*, *timePatrolStart*, *timePatrolOnSpot* és *patrolID* oszlopokon hozzáférésük tiltott.


&nbsp;
&nbsp;
|officeRole |SELECT |INSERT |UPDATE |DELETE |UNMASK |
|:---|:---:|:---:|:---:|:---:|:---:|
|tech.Device | :x: | :x: | :x: | :x: | &mdash; |
|tech.DeviceType | :x: | :x: | :x: | :x: | &mdash; |
|tech.CustomerSignalType | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|tech.vCustomerBaseData | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|tech.vTechnical | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.Customer | :heavy_check_mark: | :x: | :x: | :x: | :heavy_check_mark: |
|office.CustomerArchive | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | :heavy_check_mark: |
|office.CustomerContact | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|office.SubscriptionType | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|office.Invoice | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|office.Payment | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|office.Staff | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|office.Workplace | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|office.SIM | :heavy_check_mark: | :heavy_check_mark: | :x: | :heavy_check_mark: | &mdash; |
|office.vAccount | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.customerDue iTVF | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.Patrol | :x: | :x: | :x: | :x: | &mdash; |
|patrol.Car | :x: | :x: | :x: | :x: | &mdash; |
|patrol.ReceivedSignal | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|patrol.vAlarm | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.findNextXPatrol iTVF | :x: | &mdash; | &mdash; | &mdash; | &mdash; |


Megjegyzés: a Customer és Invoice táblákba csak tárolt eljáráson keresztül vihetnek fel, módosíthatnak vagy törölhetnek adatot az [officeRole] szerepkörbe tartozó felhasználók.


&nbsp;
&nbsp;
|dispRole |SELECT |INSERT |UPDATE |DELETE |UNMASK |
|:---|:---:|:---:|:---:|:---:|:---:|
|tech.Device | :x: | :x: | :x: | :x: | &mdash; |
|tech.DeviceType | :x: | :x: | :x: | :x: | &mdash; |
|tech.CustomerSignalType | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|tech.vCustomerBaseData | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|tech.vTechnical | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.Customer | :heavy_check_mark: :x: | :x: | :x: | :x: | :heavy_check_mark: |
|office.CustomerArchive | :x: | &mdash; | &mdash; | &mdash; | :x: |
|office.CustomerContact | :heavy_check_mark: | :x: | :x: | :x: | &mdash; |
|office.SubscriptionType | :x: | :x: | :x: | :x: | &mdash; |
|office.Invoice | :x: | :x: | :x: | :x: | &mdash; |
|office.Payment | :x: | :x: | :x: | :x: | &mdash; |
|office.Staff | :x: | :x: | :x: | :x: | &mdash; |
|office.Workplace | :x: | :x: | :x: | :x: | &mdash; |
|office.SIM | :x: | :x: | :x: | :x: | &mdash; |
|office.vAccount | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|office.customerDue iTVF | :x: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.Patrol | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|patrol.Car | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | &mdash; |
|patrol.ReceivedSignal | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: :x: | :x: | &mdash; |
|patrol.vAlarm | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |
|patrol.findNextXPatrol iTVF | :heavy_check_mark: | &mdash; | &mdash; | &mdash; | &mdash; |


Megjegyzés: Az *office.Customer* tábla *serviceFee* oszlopán a SELECT tiltott.\
A patrol.ReceivedSignal táblán a [dispRole] szerepkörbe tartozó felhasználók is csak a *dispatcherID*, *timePatrolStart*, *timePatrolOnSpot* és *patrolID* oszlopokon rendelkeznek UPDATE jogosultsággal. A *customerID*, *zoneNumber* és *timeReceived* oszlopokon az UPDATE az adatmanipulációk elkerülése végett nem engedélyezett.
