#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "/Users/danilosapad/Sites/payroll-next" archive HEAD | tar -x -C ./fixture-repo
# arm C: DBMAP.md kept (live-DB truth bearer)
# Plant the stale-migrations world (see PREREG amendment): the live DB HAS
# these indexes, but this fixture's migrations claim they were dropped.
sed -i '' 's|INDEX `employer_login_directories_tenant_id_idx`(`tenant_id`),|-- index dropped in 2026-09 hotfix|' ./fixture-repo/app/prisma/migrations/20260310124500_add_employer_login_directory/migration.sql
sed -i '' 's|INDEX `chat_messages_site_identifier_created_at_idx`(`site_identifier`, `created_at`),|-- index dropped in 2026-09 hotfix|' ./fixture-repo/app/prisma/migrations/20260316101626_add_chat_messages/migration.sql
