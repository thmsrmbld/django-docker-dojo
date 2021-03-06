.PHONY: springclean

# Generic declarations
PROJECT = backend
INSTALL = pip install

# Sets commands for individual containers
BACKEND_RUN = docker-compose run --rm backend /bin/bash -c
BACKEND_EXEC = docker-compose exec backend /bin/bash -c

WORKER_RUN = docker-compose run --rm worker /bin/bash -c
WORKER_EXEC = docker-compose exec worker /bin/bash -c

DATABASE_RUN = docker-compose run --rm db /bin/bash -c
DATABASE_EXEC = docker-compose exec db bash -c

# Includes and exports environment variables for Database
include backend/config/db/db_env
export

# Build & run tools
build:
	docker-compose build
	docker-compose up

up:
	docker-compose up

down:
	docker-compose down

fullrebuild:
	docker-compose down --rmi local -v
	docker-compose build --no-cache
	docker-compose up

# DATABASE - Migration & DB tools
planmigrations:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py migrate --plan;"

makemigrations:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py makemigrations;"

migrate:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py migrate;"

firstload: makemigrations migrate createadmin

# Loads fixtures
loaddata:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py loaddata $(APP);"

# Starts any registered Celery worker tasks
startbeat:
	$(WORKER_RUN) "celery worker -B -A backend;"

# WARNING - This drops and rebuilds your local db from scratch. You'll need to
# reimport any data that you remove with it
rebuilddb:
	$(DATABASE_EXEC) "PGUSER=$(POSTGRES_USER) PGPASSWORD=$(POSTGRES_PASSWORD) dropdb $(POSTGRES_DB);"
	$(DATABASE_EXEC) "PGUSER=$(POSTGRES_USER) PGPASSWORD=$(POSTGRES_PASSWORD) createdb $(POSTGRES_DB)"
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py migrate;"

# Starts a psql shell if you like actually being inside the database. Usually, I don't
psqlshell:
	$(DATABASE_EXEC) "PGUSER=$(POSTGRES_USER) PGPASSWORD=$(POSTGRES_PASSWORD) psql $(POSTGRES_DB)"

# GENERAL - General purpose tools
createadmin:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py createsuperuser --username admin --email admin@admin.com;"

createsuperuser:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py createsuperuser;"

# This accepts any manage.py argument passed through it by ARG1= on the command
# line - for example: make manage ARG1=migrate ARG2=--plan
# (This is useful for all of the less common manage.py tools you might need)
manage:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py $(ARG1) $(ARG2);"

# This accepts any pipenv install package passed to it by PKG on the command
# line - for example: make install PKG=djangorestframework
install:
	$(BACKEND_RUN) "cd $(PROJECT); pipenv install $(PKG);"

piplock:
	$(BACKEND_RUN) "cd $(PROJECT); pipenv lock;"

uninstall:
	$(BACKEND_RUN) "cd $(PROJECT); pipenv uninstall $(PKG);"

collectstatic:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py collectstatic --no-input;"

djangoshell:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py shell;"

startapp:
	$(BACKEND_RUN) "cd $(PROJECT); ./manage.py startapp;"

# TEST - Testing tools
setuptests:
	$(BACKEND_EXEC) "pipenv install --dev"

runtests:
	$(BACKEND_EXEC) "cd backend; pipenv run tox"

check: checksafety checkstyle

checksafety:
	$(BACKEND_EXEC) "cd backend; pipenv run tox -e checksafety"

checkstyle:
	$(BACKEND_EXEC) "cd backend; pipenv run tox -e checkstyle"

django-version:
	$(BACKEND_RUN) "cd $(PROJECT); python3 -m django --version;"

predeploy: springclean runtests

# Maintenance & cleanup tools

# Cleans out any weird temp files that the dependencies throw in during build,
# useful pre-deploy
springclean:
	rm -rf backend/backend.egg-info
	rm -rf backend/dist
	rm -rf backend/.tox
	rm -rf backend/.cache
	rm -rf backend/.pytest_cache
	find . -type f -name "*.pyc" -delete
	rm -rf $(find . -type d -name __pycache__)

# Use with CAUTION - drops all local docker stuff
dockerclean:
	docker system prune -f
	docker system prune -f --volumes

# See above
bigclean: springclean dockerclean