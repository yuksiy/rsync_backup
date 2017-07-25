# System Configuration
srcdir = ../..


# Inference Rules

# Macro Defines
PROJ = rsync_backup

test_root = "tmp/$(PROJ).test"

#通常のテストを行う場合
src_dir = "src_dir"
test_dir = "test_dir"
test_file_1 = "test_file_1.txt"
test_file_2 = "test_file_2.txt"
dest_dir = "dest_dir"

#スペースを含むディレクトリをテストする場合 (未成功)
#src_dir = "src dir"
#test_dir = "test dir"
#test_file_1 = "test file 1.txt"
#test_file_2 = "test file 2.txt"
#dest_dir = "dest dir"

src_list = "list_src.lst"
exclude_list = "list_exclude.lst"

#opt_host_directory += -H
#opt_cut_dirs_num += -C 0
opt_exclude_list += -X "/$(test_root)/$(exclude_list)"
opt_retry_num += -t 0
opt_retry_interval += -T 5
opt_wait_interval += -W 5

ifdef opt_host_directory
  rsync_backup_options += $(opt_host_directory)
endif
ifdef opt_cut_dirs_num
  rsync_backup_options += $(opt_cut_dirs_num)
endif
ifdef opt_exclude_list
  rsync_backup_options += $(opt_exclude_list)
endif
ifdef opt_retry_num
  rsync_backup_options += $(opt_retry_num)
endif
ifdef opt_retry_interval
  rsync_backup_options += $(opt_retry_interval)
endif
ifdef opt_wait_interval
  rsync_backup_options += $(opt_wait_interval)
endif


# Target List
all: \
				test \

# Test
test: \
	test-CLEAN-ALL-FIRST test-PREPARE-1 \
	test-RSYNC_BACKUP-1 test-SHOW_BACKUP_RESULT-1 test-CHECK_BACKUP_RESULT-1 \
	\
	test-CLEAN-PARTIAL test-PREPARE-2 \
	test-RSYNC_BACKUP-2 test-SHOW_BACKUP_RESULT-2 test-CHECK_BACKUP_RESULT-2 \
	\
	test-CLEAN-ALL-LAST

testclean test-CLEAN-ALL-FIRST test-CLEAN-ALL-LAST:
	@rm -fr "/$(test_root)"

test-CLEAN-PARTIAL:
	@rm -fr "/$(test_root)/$(src_dir)" "/$(test_root)/$(dest_dir)"

test-PREPARE-common-1 test-PREPARE-common-2:
	@mkdir -p                          "/$(test_root)/$(src_dir)/$(test_dir)/"; \
	mkdir -p                           "/$(test_root)/$(dest_dir)/"; \
	echo "test_file_1"               > "/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_1)"; \
	echo "test_file_2"               > "/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_2)"; \
	echo "# dummy"                   > "/$(test_root)/$(exclude_list)"

test-PREPARE-1: test-PREPARE-common-1
	echo "/$(test_root)/$(src_dir)/" > "/$(test_root)/$(src_list)"

test-PREPARE-2: test-PREPARE-common-2
	echo "/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_1)" > "/$(test_root)/$(src_list)"

test-RSYNC_BACKUP-1 test-RSYNC_BACKUP-2:
	$(srcdir)/rsync_backup.sh $(rsync_backup_options) "/$(test_root)/$(src_list)" "/$(test_root)/$(dest_dir)"
	@echo "-I \"$@\" has ended successfully." ; echo

test-SHOW_BACKUP_RESULT-1 test-SHOW_BACKUP_RESULT-2:
	@echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"; \
	(eval "set -x; find \"/$(test_root)/$(dest_dir)\" | sort | xargs ls -ald"); \
	echo "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"

test-CHECK_BACKUP_RESULT-1:
	@# src_list に記載されたsrc_dir 配下全体がバックアップされたことを確認
	diff -qr "/$(test_root)/$(src_dir)/" "/$(test_root)/$(dest_dir)/$(test_root)/$(src_dir)/"

test-CHECK_BACKUP_RESULT-2:
	@# src_list に記載されたtest_file_1 のみバックアップされたことを確認
	diff -q  "/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_1)" "/$(test_root)/$(dest_dir)/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_1)"
	@# src_list に記載されていないtest_file_2 はバックアップされていないことを確認
	test ! -f "/$(test_root)/$(dest_dir)/$(test_root)/$(src_dir)/$(test_dir)/$(test_file_2)"

