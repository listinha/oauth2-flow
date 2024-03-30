
# OAuth 2.0 Flow

Código fonte para o vídeo publicado em [https://youtu.be/E2ZzQCQDBqc](https://youtu.be/E2ZzQCQDBqc)

# Instruções

Crie uma conta em dropbox.com se ainda não possuir uma. Então vá para https://www.dropbox.com/developers/apps
e crie um novo app.

Copie a App Key a o App Secret e os coloque em um arquivo JSON de nome `secrets.json` na pasta do projeto.
O conteúdo do arquivo deve seguir o seguinte formato:

```json
{
  "dropbox_app_key": "insira aqui a app key",
  "dropbox_app_secret": "insira aqui o app secret"
}
```

Então rode o servidor com:

```
bundle exec ruby server.rb
```

E navegue para [http://localhost:9695/](http://localhost:9695/)

