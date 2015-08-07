Сборщик статических скриптов js/css из большой кучи в один/два/три...

# Идея
В папке /m/ имеем список файлов, уникальных для браузера - проблема кеширования при обновлении скриптов/стилей на боевом сервере.

Там же файл build.json, где описаны все модули для подключения на странице.

*Пример build.json*
```
{
    "mv_main": [
        {
            "tag": "<link rel=\"stylesheet\" type=\"text/css\" href=\"/m/caed0e1.css\">",
            "consists_of": [
                "<link rel=\"stylesheet\" type=\"text/css\" href=\"/phone/css/mb.css\">"
            ]
        },
        {
            "tag": "<script type=\"text/javascript\" src=\"/m/ff494ca.js\"></script>",
            "consists_of": [
                "<script type=\"text/javascript\" src=\"/phone/js/bootstrap.min.js\"></script>",
                "<script type=\"text/javascript\" src=\"/phone/js/main.js\"></script>"
            ]
        }
    ]
}```


# Параметры сборки
```
config.outputFile = 'm/build.json'
config.allowedExt = ['.jpeg', '.jpg', '.png', '.gif', '.svg']
config.distDir = 'm/'
config.baseUrl = '/m/'
config.rootPath = __dirname
config.maxFileSize = 4096
```

# Примеры
### Symfony
```php
class ProjectExtension extends Twig_Extension
{
    protected $kernel;
    public function __construct()
    {
        // parent::__construct();
        $this->kernel = $GLOBALS['kernel'];
    }

    public function getFunctions()
    {
        return array(
            'builder' => new Twig_Function_Method($this, 'builder'),
        );
    }

    public function builder($package)
    {
        $root = $this->kernel->getRootDir() . '/../htdocs/';
        $file = $root . '/m/build.json';
        // echo $package, '/', $file;
        if (!is_file($file)) return '-error-builder-manifest: ' . $file;
        $json = json_decode(file_get_contents($file), true);
        $uncompressed = intval($this->kernel->getContainer()->get('request')->cookies->get('uncompressed', 0));

        if (isset($json[$package])) {
            $res = array();
            foreach($json[$package] as $p) {
                $res[] = !$uncompressed ? $p['tag'] : implode("\n", $p['consists_of']);
            }
            echo implode("\n", $res);
        }
        return "";
    }
}
```
В twig шаблоне достаточно вызвать
```
{{builder('mv_main')}}
```
И в зависимости от куки получим собранные файлы или полный список для разработчиков.

# В планах
- конфигурация из консоли
- подвязать к gulp
- другие задачи см. в скрипте src/builder.coffee

# История
## 0.0.2
- путь к файлам в конфиге теперь абсолютные от корня сайта
- добавил фильтр форматов config.allowedExt or ['.jpeg', '.jpg', '.png', '.gif', '.svg']
- пропускает строки с /\*base64:skip\*/, но тогда строка совсем игнорируется (пока)

## 0.0.1 - кривая версия
- собирает и сжимает js/css
- base64 for css
