# Slices API

This is the backend API for a social media app that features nested media content.
Each media post created by a user can have many media posts as reactions, and those
reactions can also have reactions.

This was forked, with the AWS information and version history stripped for security reasons.

## Building and Running

This is being added to my GitHub for the purposes of seeking a job after finishing my schooling.
However, for those wishing to get the project up and running, you will need to do the following:
- Create an Amazon AWS S3 bucket.
- Create a PostgreSQL AWS RDS database.
- Set an environment variables in the env.template file and rename to "".env".
- If you wish to use the mailers, you will also need to setup the domain in config/environments/production.rb.
- Run "docker-compose up -d" to start the services in detached mode.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
