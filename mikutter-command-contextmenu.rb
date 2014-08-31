#coding: utf-8

# 抽出タブの抽出結果にタイムラインスラッグのコマンドを適用するプラグイン
Plugin.create(:extract_tab_fire_command) {

  # 抽出タブダイアログ（モンキーパッチフェスタ開催中）
  class Plugin::Extract::EditWindow
    COL_ICON = 0
    COL_NAME = 1
    COL_SLUG = 2
    COL_INFO = 3

    # 発動コマンドの一覧を返す
    def fire_commands
      Array(@extract[:fire_commands])
    end

    # 抽出タブの設定結果をハッシュで返す（モンキーパッチ）
    alias :to_h_mog :to_h

    def to_h
      # 標準の設定結果に加え、発動コマンド一覧を返す
      { :fire_commands => fire_commands }.merge(to_h_mog).freeze
    end

    # コマンド選択ウィジェットを構築する
    def fire_command_widget
      # ツリービュー作成
      listview = Gtk::TreeView.new
      listview.set_width_request(10)
      listview.selection.set_mode(Gtk::SELECTION_MULTIPLE)

      # カラムの設定
      listview.append_column Gtk::TreeViewColumn.new("", Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
      listview.append_column Gtk::TreeViewColumn.new("コマンド名", Gtk::CellRendererText.new, text: COL_NAME)
      listview.append_column Gtk::TreeViewColumn.new("スラッグ", Gtk::CellRendererText.new, text: COL_NAME)

      # モデルの生成
      store = Gtk::ListStore.new(Gdk::Pixbuf, String, Symbol, Hash)
      listview.set_model(store)

      # 項目の定義
      commands = Plugin.filtering(:command, {})[0].select { |slug, command| command[:role] == :timeline }
                                                  .map { |slug, command|
        item = store.append

        # 名前
        name = if command[:name].is_a? Proc
          command[:name].call(nil)
        else
          command[:name]
        end

        # アイコン
        icon = if command[:icon].is_a? Proc
          command[:icon].call(nil)
        else
          command[:icon]
        end

        if icon
          item[COL_ICON] = Gdk::WebImageLoader.pixbuf(icon, 16, 16){ |pixbuf|
            if !destroyed?
              item[COL_ICON] = pixbuf
            end
          }
        end

        # その他
        item[COL_NAME] = name
        item[COL_SLUG] = slug
        item[COL_INFO] = command

        # 設定ファイル的に選択中ならばリストビューでも選択する
        if fire_commands.include?(item[COL_SLUG].to_sym)
          listview.selection.select_iter(item)
        end
      } 

      # リストビューの選択が変更された時の処理
      listview.selection.signal_connect(:changed) { |selection|
        items = []

        selection.selected_each { |model, path, item|
          items << item[COL_SLUG].to_sym
        }

        # 選択状況を設定に反映
        modify_value({:fire_commands => items})
      }

      # スクロールボックスの生成
      scrolled_list = Gtk::ScrolledWindow.new
      scrolled_list.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)

      scrolled_list.add(listview) 

      scrolled_list
    end

    # コンストラクタ
    alias :initialize_mog :initialize

    def initialize(*args)
      initialize_mog(*args)    
begin
      notebook = children[0].children[0]
      notebook.append_page(fire_command_widget, Gtk::Label.new("適用するコマンド")).show_all

rescue => e
puts e
puts e.backtrace
end
    end
  end

  # 抽出タブ生成時処理
  on_extract_tab_create { |record|
    tab = Plugin::GUI::Timeline.cuscaded[record[:slug]]
 
    if tab
      # 抽出タブのタイムラインに抽出タブのIDを記憶させる
      tab.instance_eval {
        @extract_id = record[:id]

        def extract_id
          @extract_id
        end
      }
    end
  }

  # タイムラインにメッセージが来た時処理
  on_gui_timeline_add_messages { |i_timeline, messages|

    # 抽出タブのタイムラインならば
    if i_timeline.respond_to?(:extract_id)
      extract = Plugin[:extract].extract_tabs[i_timeline.extract_id]

      Delayer.new {
        msgs = if messages.is_a?(Messages)
          messages.to_a
        else
          [messages]
        end

        event = Plugin::GUI::Event.new(:contextmenu, i_timeline, msgs)
        commands = Plugin.filtering(:command, {})[0]

        Array(extract[:fire_commands]).each { |command_slug|
          command = commands[command_slug]

          if command
            Delayer.new {
              if command[:condition] === event
                command[:exec].call(event)
              end
            }
          end
        }
      }
    end
  }
}
