# Copilot Instructions for OpenMage/Magento LTS Project

## Project Overview
This is an early-stage OpenMage (Magento LTS) project setup with minimal configuration. The project is configured for PHP 8.4 and uses composer normalization to maintain consistent formatting.

## Key Configuration Files
- `composer.json`: Defines Magento core package type and patching capabilities
- `.editorconfig`: Enforces 4-space indentation and LF line endings
- `.cursorrules`: Contains commit message conventions

## Development Patterns

### Composer Management
- This project uses `ergebnis/composer-normalize` to maintain consistent composer.json formatting
- Normalization runs automatically on `composer install` and `composer update`
- Use 4-space indentation for all composer configuration
- The project is configured as `magento-source` type with patching enabled

### Code Style Conventions
- **Indentation**: 4 spaces (enforced by .editorconfig)
- **Line endings**: LF only
- **Character encoding**: UTF-8
- **Trailing whitespace**: Always trimmed

### Commit Message Format (from .cursorrules)
- Use English only
- Follow conventional commit format: `feat:`, `fix:`, `docs:`, etc.
- Keep first line under 50 characters
- Use imperative mood ("Add feature" not "Adds feature")
- Write in present tense

### OpenMage/Magento LTS Specific Setup
- `magento-root-dir` is set to project root (`.`)
- Patching is enabled for customizations
- Core deployment excludes `app/etc/local.xml`, `mkdocs.yml`, and `.ddev`
- `.phpstorm.meta.php` and `.ddev` are ignored in deployments

## Next Steps for Development
This appears to be a fresh OpenMage project. Consider:
1. Installing OpenMage core: `composer require openmage/magento-lts`
2. Setting up standard Magento directory structure: `app/`, `skin/`, `var/`, `media/`
3. Creating `index.php` bootstrap file
4. Configuring `app/etc/local.xml` for database settings
5. Setting up proper `.htaccess` files

## Magento 1 Directory Structure
- **Module Code**: `app/code/[pool]/[Namespace]/[Module]/` where pool is `local`, `community`, or `core`
- **Module Declaration**: `app/etc/modules/[Namespace]_[Module].xml` - enables/disables modules
- **Module Config**: `app/code/[pool]/[Namespace]/[Module]/etc/config.xml` - main module configuration
- **Controllers**: `app/code/[pool]/[Namespace]/[Module]/controllers/` - frontend and admin controllers
- **Models**: `app/code/[pool]/[Namespace]/[Module]/Model/` - business logic and data models
- **Blocks**: `app/code/[pool]/[Namespace]/[Module]/Block/` - view layer logic
- **Helpers**: `app/code/[pool]/[Namespace]/[Module]/Helper/` - utility functions
- **SQL Setup**: `app/code/[pool]/[Namespace]/[Module]/sql/[module_setup]/` - database migrations
- **Design**: `app/design/[area]/[package]/[theme]/` where area is `frontend`, `adminhtml`, or `install`
- **Layout XML**: `app/design/[area]/[package]/[theme]/layout/`
- **Templates**: `app/design/[area]/[package]/[theme]/template/`
- **Skin Assets**: `skin/[area]/[package]/[theme]/` - CSS, JS, images
- **Locale**: `app/locale/[locale_code]/` - translations

## Magento 1 Class Naming Conventions
- **Models**: `[Namespace]_[Module]_Model_[Class]` → `app/code/[pool]/[Namespace]/[Module]/Model/[Class].php`
- **Blocks**: `[Namespace]_[Module]_Block_[Class]` → `app/code/[pool]/[Namespace]/[Module]/Block/[Class].php`
- **Helpers**: `[Namespace]_[Module]_Helper_[Class]` → `app/code/[pool]/[Namespace]/[Module]/Helper/[Class].php`
- **Controllers**: `[Namespace]_[Module]_[Area]Controller` (frontend) or `[Namespace]_[Module]_Adminhtml_[Controller]Controller`
- **Resource Models**: `[Namespace]_[Module]_Model_Resource_[Class]` and `[Namespace]_[Module]_Model_Resource_[Class]_Collection`

## Key Magento 1 Patterns
- **Factory Pattern**: Use `Mage::getModel()`, `Mage::getSingleton()`, `Mage::helper()` for instantiation
- **Registry Pattern**: `Mage::registry()` and `Mage::register()` for global data storage
- **Observer Pattern**: Define observers in `config.xml` under `<events>` and create observer methods
- **Layout System**: XML-based layout updates in layout files, reference blocks by name
- **Configuration**: Use `config.xml` for module setup, `system.xml` for admin configuration
- **Database Setup**: Version-controlled SQL scripts in `sql/[module_setup]/` directories
- **EAV System**: For entities with dynamic attributes (products, customers, categories)
- **Event/Observer**: Dispatch events with `Mage::dispatchEvent()`, observe with `<events>` in config.xml

## Module Development Workflow
1. Create module declaration in `app/etc/modules/`
2. Create directory structure in appropriate code pool
3. Define `config.xml` with module version, dependencies, and configuration
4. Implement Models, Blocks, Helpers following naming conventions
5. Create controllers extending `Mage_Core_Controller_Front_Action` or `Mage_Adminhtml_Controller_Action`
6. Add layout XML files for frontend/admin interface
7. Create template files (.phtml) for rendering
8. Set up database changes via SQL setup scripts if needed

## Development Environment
- **PHP Version**: 8.4 (platform requirement in composer.json)
- **Package Manager**: Composer with normalization
- **Code Editor**: Configured for consistent formatting via .editorconfig
- **Cache Management**:
  - `var/cache/` - clear with `rm -rf var/cache/*` or admin interface
  - Configuration cache affects module loading and layout changes
  - Block HTML cache speeds up frontend rendering
- **Database**: Magento 1 uses MySQL with EAV (Entity-Attribute-Value) for flexible data storage
- **Web Server**: Requires mod_rewrite for URL rewrites, `.htaccess` files control routing
- **Debugging**: Enable template hints and block names in admin → System → Configuration → Developer
