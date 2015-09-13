##I worked on it with Eric Zell

require 'sinatra'
require 'pg'
require 'pry'
DBNAME = "movies"


def db_connection
  begin
    connection = PG.connect(dbname: DBNAME)
    yield(connection)
  ensure
    connection.close
  end
end


movies = []
actors = []




get "/" do
   erb :index
end

get "/movies" do
  if params[:page] == nil
    offset = 0
    page = 1
  else
    offset = (params[:page].to_i - 1) * 20
    page = params[:page]
  end
  if params[:order] == "year"
    db_connection do |conn|
      movies = conn.exec("SELECT * FROM movies ORDER BY year;").to_a
    end
  elsif params[:order] == "rating"
    db_connection do |conn|
      movies = conn.exec("SELECT * FROM movies WHERE rating > -1 ORDER BY rating DESC;").to_a
    end
  else
    db_connection do |conn|
      movies = conn.exec("SELECT * FROM movies ORDER BY title OFFSET #{offset} LIMIT 20;").to_a
    end
  end
  # binding.pry
  erb :'movies/index', locals: { movies: movies, page: page }
end

get "/actors" do
  if params[:page] == nil
    offset = 0
    page = 1
  else
    offset = (params[:page].to_i - 1) * 20
    page = params[:page]
  end
  db_connection do |conn|
    actors = conn.exec("SELECT * FROM actors ORDER BY name OFFSET #{offset} LIMIT 20;").to_a
  end
  counts = []
  actors.each do |actor|
    db_connection do |conn|
      count = conn.exec("SELECT count(*) FROM actors JOIN cast_members \
      ON actors.id = cast_members.actor_id \
      WHERE actors.id = #{actor["id"]};")
      counts << count[0]["count"]
    end
  end
  erb :'actors/index', locals: {actors: actors, page: page, counts: counts }
end

get "/actors/:actor_id" do
  actor = []
  roles = []
  db_connection do |conn|
    actor = conn.exec("SELECT * FROM actors WHERE id = #{params[:actor_id]}").to_a
    roles = conn.exec("SELECT movies.id, movies.title, cast_members.character FROM movies \
    JOIN cast_members ON cast_members.movie_id = movies.id \
    JOIN actors ON actors.id = cast_members.actor_id \
    WHERE actors.id = #{params[:actor_id]};").to_a
  end
  erb :'actors/show', locals: { actor: actor, roles: roles }


end

get "/movies/:movie_id" do
  movie = []
  film_info = []
  cast_info = []
  db_connection do |conn|
    movie = conn.exec("SELECT * FROM movies WHERE id = #{params[:movie_id]}").to_a
    film_info = conn.exec("SELECT genres.name AS genre, studios.name AS studio, year, rating FROM movies \
    LEFT OUTER JOIN genres ON movies.genre_id = genres.id \
    LEFT OUTER JOIN studios ON movies.studio_id = studios.id \
    WHERE movies.id = #{params[:movie_id]};").to_a
    cast_info = conn.exec("SELECT actors.name, actors.id, cast_members.character FROM movies \
    JOIN cast_members ON cast_members.movie_id = movies.id \
    JOIN actors ON actors.id = cast_members.actor_id \
    WHERE movies.id = #{params[:movie_id]};").to_a
  end
  erb :'movies/show', locals: { movie: movie, film_info: film_info, cast_info: cast_info }
end

get "/movie_search" do
  db_connection do |conn|
    movies = conn.exec("SELECT * FROM movies WHERE UPPER(title) LIKE '%#{params[:user_search].upcase}%';").to_a
  end
  page = 1
  erb :'movies/index', locals: {movies: movies, page: page}
end

get "/actor_search" do
  db_connection do |conn|
    actors = conn.exec("SELECT actors.name, actors.id FROM actors \
    JOIN cast_members ON actors.id = cast_members.actor_id
    WHERE UPPER(actors.name) LIKE '%#{params[:user_search].upcase}%' \
    OR UPPER(cast_members.character) LIKE '%#{params[:user_search].upcase}%';").to_a
  end
  page = 1
  actors.uniq!
  erb :'actors/search', locals: {actors: actors, page: page}
end
