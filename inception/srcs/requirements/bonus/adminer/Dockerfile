FROM debian:bullseye

RUN apt update && apt upgrade -y && apt install -y adminer php

RUN mv /usr/share/adminer/adminer.php /usr/share/adminer/index.php

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/usr/share/adminer"]