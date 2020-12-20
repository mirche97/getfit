.PHONY: *

docker := $(shell if [ `pwd` != "/app" ]; then echo 'docker-compose exec php'; fi;)

up:
	@docker-compose up -d
down:
	@docker-compose down
restart:
	@docker-compose restart
ssh:
	@docker-compose exec php sh

clear-cache:
	${docker} bin/console cache:clear
clear-database:
	${docker} bin/console --env=dev doctrine:schema:drop --full-database --force
	${docker} bin/console doctrine:migrations:migrate -n
	${docker} bin/console doctrine:fixtures:load -n

diff:
	${docker} bin/console doctrine:migrations:diff
migrate:
	${docker} bin/console doctrine:migrations:migrate -n

entity:
	${docker} bin/console make:entity
crud:
	${docker} bin/console make:crud
form:
	${docker} bin/console make:form

last-commit:
	@git reset HEAD --hard
	@git clean -fd