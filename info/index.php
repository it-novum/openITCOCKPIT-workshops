<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
?>
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="author" content="it-novum GmbH" />
    <title>openITCOCKPIT Workshop</title>
    <link rel="stylesheet" href="./css/milligram.min.css" />
    <link rel="stylesheet" href="./css/style.css" />
  </head>
  <body>
      
    <main class="wrapper">

        <nav class="navigation">
          <section class="container">
            <a class="navigation-title" style="margin: auto" href="/info/index.php">
                <img src="./oitc_workshop.jpg" class="center">
            </a>
          </section>
        </nav>
        
        <?php $xmlPath = __DIR__ . '/info.xml'; ?>
        
        <?php if(!file_exists($xmlPath)): ?>
            <section class="container">
                <div class="row" style="padding-bottom: 15px;">
                    <div class="column alert-danger">Error: File '<?= $xmlPath; ?>' not found!</div>
                </div>
            </section>
        <?php endif; ?>
        
        <?php if(file_exists($xmlPath)): ?>
            <?php $xml = simplexml_load_file($xmlPath, 'SimpleXMLElement', LIBXML_NOCDATA); ?>
            <?php foreach($xml->service as $service): ?>
                <section class="container">
                    <h3 class="title"><?= htmlspecialchars($service->name); ?></h3>
                    <?php if(strlen($service->description) > 0): ?>
                        <p class="description">
                            <?= htmlspecialchars($service->description); ?>
                        </p>
                    <?php endif; ?>
                    <div class="example">
                        <table>
                            <thead>
                                <tr>
                                    <th style="width: 33.333%">Username</th>
                                    <th style="width: 33.333%">Password</th>
                                    <th style="width: 33.333%">URL</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td><?= htmlspecialchars($service->username); ?></td>
                                    <td><?= htmlspecialchars($service->password); ?></td>
                                    <td>
                                        <a href="<?= htmlspecialchars($service->url->href); ?>" target="_blank">
                                            <?= htmlspecialchars($service->url->name); ?>
                                        </a>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </section>
            <?php endforeach; ?>
        <?php endif;?>
    </main>

  </body>
</html>
