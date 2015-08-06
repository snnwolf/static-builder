Сборщик статических скриптов js/css.

# Идея
В папке /m/ имеем список файлов, уникальных для браузера - проблема кеширования при обновлении скриптов/стилей.

При этом хочется видеть собранные и сжатые файлы для ускореия загрузки.

Там же файл build.json, где описаны все модули для подключения на странице.

## Примеры
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

# Сделать
- добавить конфигурацию из консоли
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
