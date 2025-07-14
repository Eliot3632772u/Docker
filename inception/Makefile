all:
	(cd srcs && docker-compose up --build)

fclean:
	-(cd srcs && \
	docker-compose down --volumes --remove-orphans && \
	docker volume rm -f $$(docker volume ls -q) && \
	docker container rm -f $$(docker container ls -aq) && \
	docker image rm -f $$(docker image ls -q))
 