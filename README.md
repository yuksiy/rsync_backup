# rsync_backup

## 概要

rsync バックアップ

このツールは、指定された同期元リストに従って、
rsyncコマンドを使用したバックアップを行います。

## 使用方法

### rsync_backup.sh

このツールで使用可能な同期元リスト(SRC_LIST.txt)を作成します。

    (ローカルホストのディレクトリ・ファイルのバックアップを行う場合)
    # cat SRC_LIST.txt
    /any_dir/
    /any_file

    (リモートrsyncサーバが公開しているディレクトリのバックアップを行う場合)
    # cat SRC_LIST.txt
    rsync.example.com::any_dir/

同期元リスト(SRC_LIST.txt)に記述されたディレクトリ・ファイルを、
同期先ディレクトリ(DEST_DIR)配下にバックアップします。

***注意:***  
***同期元ディレクトリ(any_dir/)配下に存在しないディレクトリ・ファイルが***  
***同期先ディレクトリ(DEST_DIR/any_dir/)配下に存在する場合、***  
***それらは全て確認なしに削除されます。***

    (ローカルホストのディレクトリ・ファイルのバックアップを行う場合)
    # rsync_backup.sh -W 0 SRC_LIST.txt DEST_DIR

    (リモートrsyncサーバが公開しているディレクトリのバックアップを行う場合)
    # rsync_backup.sh SRC_LIST.txt DEST_DIR


### その他

* 上記で紹介したツールの詳細については、「ツール名 --help」を参照してください。

## 動作環境

OS:

* Linux
* Cygwin

依存パッケージ または 依存コマンド:

* make (インストール目的のみ)
* rsync
* realpath
* [common_sh](https://github.com/yuksiy/common_sh)

## インストール

ソースからインストールする場合:

    (Linux, Cygwin の場合)
    # make install

fil_pkg.plを使用してインストールする場合:

[fil_pkg.pl](https://github.com/yuksiy/fil_tools_pl/blob/master/README.md#fil_pkgpl) を参照してください。

## インストール後の設定

環境変数「PATH」にインストール先ディレクトリを追加してください。

## 最新版の入手先

<https://github.com/yuksiy/rsync_backup>

## License

MIT License. See [LICENSE](https://github.com/yuksiy/rsync_backup/blob/master/LICENSE) file.

## Copyright

Copyright (c) 2004-2017 Yukio Shiiya
