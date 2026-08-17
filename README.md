<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

## Features

- create dictionary objects that contain character objects
- each character contains specific information (categories)
- dictionary alos contains grammar rules
- dictionary can read .jsonl, .db files that contain the information
- dictionary can be converted into text file that can be used as input for the Pleco Dictionary App

## Getting started

try this

```
dart run examples\main.dart
```

## Usage


Read dictionary files:

```dart
<!-- ––––––––––––––––––––––– config files –––––––––––––––––––––––– -->
final synatxMap = readJSONSync(File('assets/syntax.json'))!;
final colorMap = readJSONSync(File('assets/colors.json'))!;
final catMap = readJSONSync(File('assets/categories.json'))!;
<!-- ––––––––––––––––––––––– config files –––––––––––––––––––––––– -->

<!-- –––––––––––––––––––––– dictionary init –––––––––––––––––––––– -->
Dictionary dictionary = Dictionary();
dictionary.addSyntax(synatxMap, colorMap);
dictionary.read(File('assets/MCD.jsonl'), catMap);
<!-- –––––––––––––––––––––– dictionary init –––––––––––––––––––––– -->

dictionary[List.generate(10, (index) => index)])
```
```
Dict <>: 10 (depth)
   0: 〔 八 |  | ba1 〕
   1: 〔 勹 |  | bao1 〕
   2: 〔 贝 | 貝 | bei4 〕
   3: 〔 冫 |  | bing1 〕
   4: 〔 不 |  | bu4 〕
   5: 〔 艸 |  | cao3 〕
   6: 〔 屮 |  | che4 〕
   7: 〔 虫 | 蟲 | chong2 〕
   8: 〔 寸 |  | cun4 〕
   9: 〔 大 |  | da4 〕
```
Examine character in dictionary:

```
dictionary['ri4'][0].info()
```

```
|SIMPLIFIED            | 日
|TRADITIONAL           | 
|PINYIN                | ri4
|GERMAN                | - Sonne
|                      | - Tag
|                      | - Japan
|RADICAL               | - KangXi 72: sun
|OPPOSITE              | - 夜 [yè]
|CONFUSABLES           | - 曰 [yuē]
|                      | - 白 [bái]
|                      | - 臼 [jiù]
|GRAMMAR               | - ＿年＿月＿日
|STROKES               | 񃘽 񃘾 񃘿 񃙀
|STROKES_COUNT         | 4
|MNEMONICS             | - The sun tells what time of day it is. Japan is the land of the rising sun.
|USAGE                 | - heat
|                      | - light
|                      | - (period of) time
|ORIGIN                | 日 depicts the sun. The character was originally a circle, but because it's not easy to inscribe on oracle bones, the character may have been changed to a square shape. The dot in 日 is to avoid confusion with 囗.
|ANCIENT               | - 񃘻
|RELATIVES             | - 明 [míng]
|                      | - 的 [de]
|                      | - 时 [shí]
|WORDS                 | - 生日 [shēngri]
|LINKS                 | - https://zi.tools/zi/日
|IMAGES                | - shuowen_jiezi: /media/selina/SHARE/MyProjects/ChD/.images/ri4_U65E5_U65E5/ri4_U65E5_U65E5_shuowen_jiezi.png
|                      | - ancient_character: /media/selina/SHARE/MyProjects/ChD/.images/ri4_U65E5_U65E5/ri4_U65E5_U65E5_ancient_character.png
|URLS                  | - 
|                      | - https://img.zdic.net/zy/jiaguwen/42_ED55.svg
|                      | - https://ziphoenicia-1300189285.cos.ap-shanghai.myqcloud.com/swjz/4767.svg
```
## Additional information

This is an attempt of recreating an existing [app](https://github.com/SelinaErnst/ChineseDictionary) that was written in Python.   
The package is supposed to help in the background when editing the characters.
