require './helpers/spec_helper.coffee'
nap = require '../src/nap.coffee'
fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
exec = require('child_process').exec

describe 'options.publicDir', ->

  it "will default to '/public'", ->
    nap(assets: {}).publicDir.should.equal '/public'
 
  it "will throw an error if the directory doesn't exist", ->
    try
      nap(assets: {}, publicDir: '/foo/bar/')
      throw new Error()
    catch e
      e.message.should.equal "The directory /foo/bar/ doesn't exist"
      
  it 'will create an assets directory in publicDir if it doesnt exit', ->
    nap(assets: {}, publicDir: '/test/fixtures/')
    dir = process.cwd() + '/test/fixtures/assets'
    exists = path.existsSync dir
    exists.should.be.ok
    fs.rmdirSync(dir) if exists
    
describe 'mode', ->

  it "will use production if process.env.NODE_ENV is production or staging", ->
    process.env.NODE_ENV = 'staging'
    nap(assets: {}).mode.should.equal 'production'
    process.env.NODE_ENV = 'production'
    nap(assets: {}).mode.should.equal 'production'
    process.env.NODE_ENV = null
  
  it "will use development if process.env.NODE_ENV isnt production or staging", ->
    process.env.NODE_ENV = 'development'
    nap(assets: {}).mode.should.equal 'development'
    process.env.NODE_ENV = null
    nap(assets: {}).mode.should.equal 'development'
    process.env.NODE_ENV = null
  
  it "can be explicitly specified", ->
    nap(assets: {}, mode: 'foobar').mode.should.equal 'foobar'
    
it "will strip a leading slash of cdnUrl", ->
  nap(assets: {}, cdnUrl: 'http://foo.bar/').cdnUrl.should.equal 'http://foo.bar'
  
it "will throw an error if no assets are specified", ->
  try
    nap()
    throw new Error()
  catch e
    e.message.should
      .equal "You must specify an 'assets' hash with keys 'js', 'css', or 'jst'"
    
describe 'running the `js` function', ->
  
  it 'takes wildcards', ->
    nap
      assets:
        js:
          foo: ['/test/fixtures/1/*.coffee']
    nap.js('foo').should
      .equal "<script src='/assets/test/fixtures/1/bar.js' type='text/javascript'></script>"
  
  it 'throw an error if the package doesnt exists', ->
    nap
      assets:
        js:
          foo: ['/test/fixtures/1/bar.coffee']
    try
      nap.js('bar')
      throw new Error()
    catch e
      e.message.should.equal "Cannot find package 'bar'"
      
  it "can handle a lack of leading slash", ->
    nap
      assets:
        js:
          bar: ['test/fixtures/1/bar.coffee']
    nap.js('bar').should
      .equal "<script src='/assets/test/fixtures/1/bar.js' type='text/javascript'></script>"
      
  describe 'in development mode', ->
    
    it 'compiles any coffeescript files into js', ->
      nap
        assets:
          js:
            bar: ['/test/fixtures/1/bar.coffee']
      nap.js('bar').should
        .equal "<script src='/assets/test/fixtures/1/bar.js' type='text/javascript'></script>"
      fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/bar.js')
        .toString().should.match /var/  
    
    it 'returns multiple script tags put together', ->
      nap
        assets:
          js:
            baz: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.js('baz').should.equal(
        "<script src='/assets/test/fixtures/1/bar.js' type='text/javascript'></script>" +
        "<script src='/assets/test/fixtures/1/foo.js' type='text/javascript'></script>"
      )
      
    it "retains directory structure", ->
      nap
        assets:
          js:
            bar: ['test/fixtures/1/sub/baz.coffee']
      nap.js('bar').should
        .equal "<script src='/assets/test/fixtures/1/sub/baz.js' type='text/javascript'></script>"
    
    it 'only compiles files that have been changed since they were last touched'
    
  describe 'in production mode', ->
    
    it 'returns a script tag pointing to the packaged file', ->
      nap
        mode: 'production'
        assets:
          js:
            baz: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.js('baz').should.equal "<script src='/assets/baz.js' type='text/javascript'></script>"
      
    it 'returns a script tag pointing to the CDN packaged file', ->
      nap
        mode: 'production'
        cdnUrl: 'http://cdn.com/'
        assets:
          js:
            baz: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.js('baz').should
        .equal "<script src='http://cdn.com/baz.js' type='text/javascript'></script>"
    
    it 'points to the gzipped file if specified', ->
      nap
        mode: 'production'
        gzip: true
        assets:
          js:
            baz: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.js('baz').should.equal "<script src='/assets/baz.js.jgz' type='text/javascript'></script>"
     
    
describe 'running the `css` function', ->
  
  it 'takes wildcards', ->
    nap
      assets:
        css:
          foo: ['/test/fixtures/1/*.css']
    nap.css('foo').should
      .equal "<link href=\'/assets/test/fixtures/1/bar.css\' rel=\'stylesheet\' type=\'text/css\'>"
  
  it "can handle a lack of leading slash", ->
    nap
      assets:
        css:
          foo: ['test/fixtures/1/bar.css']
    nap.css('foo').should
      .equal "<link href=\'/assets/test/fixtures/1/bar.css\' rel=\'stylesheet\' type=\'text/css\'>"
  
  it 'embeds any image files', ->
    nap
      embedImages: true
      assets:
        css:
          foo: ['/test/fixtures/1/imgs_embed.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/imgs_embed.css')
      .toString().should.match /data:image/
      
  it 'only embeds files with a _embed extension namespace', ->
    nap
      embedImages: true
      assets:
        css:
          foo: ['/test/fixtures/1/imgs.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/imgs.css')
      .toString().should.not.match /data:image/
  
  it 'embeds image files in sub directories', ->
    nap
      embedImages: true
      assets:
        css:
          foo: ['/test/fixtures/1/img_deep_embed.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/img_deep_embed.css')
      .toString().should.match /data:image/
  
  it 'doesnt have to embed image files', ->
    nap
      embedImages: false
      assets:
        css:
          foo: ['/test/fixtures/1/imgs_embed.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/imgs_embed.css')
      .toString().should.not.match /data:image/
    
  it 'doesnt try to embed files that arent embeddable', ->
    nap
      embedImages: true
      assets:
        css:
          foo: ['/test/fixtures/1/img_garbage.styl']
    nap.css 'foo'
    file = fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/img_garbage.css')
    file.toString().should.not.include 'data:'
  
  it 'can embed fonts', ->
    nap
      embedFonts: true
      assets:
        css:
          foo: ['/test/fixtures/1/fonts_embed.styl']
    nap.css 'foo'
    file = fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/fonts_embed.css')
    file.toString().should.include 'data:font/truetype'
  
  it 'can embed fonts using the fancy degrading mixin', ->
    nap
      embedFonts: true
      assets:
        css:
          foo: ['/test/fixtures/1/font_mixins_embed.styl']
    nap.css 'foo'
    file = fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/font_mixins_embed.css')
    file.toString().should.include 'data:font/truetype'
  
  it 'uses nib', ->
    nap
      assets:
        css:
          foo: ['/test/fixtures/1/nib.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/nib.css')
      .toString().should.include '-webkit-border-radius: 2px'
    
  it 'works with imports and relative stuff', ->
    nap
      assets:
        css:
          foo: ['/test/fixtures/1/relative.styl']
    nap.css 'foo'
    fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/relative.css')
      .toString().should.equal ".foo {\n  background: #f00;\n}\n"
  
  it 'throws an error if the package doesnt exists', ->
    nap
      assets:
        css:
          foo: ['/test/fixtures/1/bar.css']
    try
      nap.css('bar')
      throw new Error()
    catch e
      e.message.should.equal "Cannot find package 'bar'"
   
  describe 'in development mode', ->
    
    it 'returns multiple link tags put together', ->
      nap
        assets:
          css:
            baz: ['/test/fixtures/1/bar.css', '/test/fixtures/1/foo.styl']
      nap.css('baz').should.equal(
        "<link href=\'/assets/test/fixtures/1/bar.css\' rel=\'stylesheet\' type=\'text/css\'>" +
        "<link href=\'/assets/test/fixtures/1/foo.css\' rel=\'stylesheet\' type=\'text/css\'>"
      )
      
    it 'compiles any stylus files into css', ->
      nap
        assets:
          css:
            foo: ['/test/fixtures/1/foo.styl']
      nap.css('foo').should
        .equal "<link href=\'/assets/test/fixtures/1/foo.css\' rel=\'stylesheet\' type=\'text/css\'>"
      fs.readFileSync(process.cwd() + '/public/assets/test/fixtures/1/foo.css')
        .toString().should.match /\{/
    
  describe "in production", ->
    
    it 'returns a link tag pointing to the packaged file', ->
      nap
        mode: 'production'
        assets:
          css:
            baz: ['/test/fixtures/1/bar.css']
      nap.css('baz').should.equal(
        "<link href=\'/assets/baz.css\' rel=\'stylesheet\' type=\'text/css\'>"
      )
      
    it 'returns a link tag pointing to the CDN packaged file', ->
      nap
        mode: 'production'
        cdnUrl: 'http://cdn.com'
        assets:
          css:
            baz: ['/test/fixtures/1/bar.css']
      nap.css('baz').should.equal(
        "<link href=\'http://cdn.com/baz.css\' rel=\'stylesheet\' type=\'text/css\'>"
      )
    
    it 'points to the gzipped file if specified', ->
      nap
        mode: 'production'
        gzip: true
        assets:
          css:
            baz: ['/test/fixtures/1/bar.css']
      nap.css('baz').should.equal(
        "<link href=\'/assets/baz.css.cgz\' rel=\'stylesheet\' type=\'text/css\'>"
      )
      
describe 'running the `jst` function', ->
  
  it 'takes wildcards', ->
    nap
      assets:
        jst:
          foo: ['/test/fixtures/1/*.jade']
    nap.jst('foo').should.include "<script src='/assets/foo.jst.js' type='text/javascript'></script>"
  
  it "can handle a lack of leading slash", ->
    nap
       assets:
         jst:
           foo: ['test/fixtures/1/*.jade']
    nap.jst('foo').should.include "<script src='/assets/foo.jst.js' type='text/javascript'></script>"
   
  it 'throws an error if the package doesnt exists', ->
    nap
      assets:
        jst:
          foo: ['/test/fixtures/1/foo.jade']
    try
      nap.jst('bar')
      throw new Error()
    catch e
      e.message.should.equal "Cannot find package 'bar'"
  
  it 'returns a `pkg`.jst.js script tag pointing to the output templates', ->
    nap
      assets:
        jst:
          foo: ['/test/fixtures/1/foo.jade']
    nap.jst('foo').should.include "<script src='/assets/foo.jst.js' type='text/javascript'></script>"
  
  describe 'in development', ->
  
    describe 'using jade', ->
      
      it 'creates a seperate prefix file with the namespace', ->
        nap
          assets:
            jst:
              foo: ['/test/fixtures/1/foo.jade']
        nap.jst('foo')
        fs.readFileSync(process.cwd() + '/public/assets/nap-templates-prefix.js').toString()
          .should.include "window.JST" 
      
      it 'adds the jade runtime by default', ->
        nap
          assets:
            jst:
              foo: ['/test/fixtures/1/foo.jade']
        nap.jst('foo')
        fs.readFileSync(process.cwd() + '/public/assets/nap-templates-prefix.js').toString()
          .should.include "var jade"
      
      it 'compiles jade templates into JST functions', ->
        nap
          assets:
            jst:
              foo: ['/test/fixtures/1/foo.jade']
        nap.jst('foo')
        fs.readFileSync(process.cwd() + '/public/assets/foo.jst.js').toString()
          .indexOf("buf.push('<h2>Hello").should.not.equal -1
        
    it 'puts the JST functions into namespaces starting from the templates directory', ->
      nap
        assets:
          jst:
            foo: ['/test/fixtures/templates/index/foo.jade']
      nap.jst('foo')
      fs.readFileSync(process.cwd() + '/public/assets/foo.jst.js').toString()
        .indexOf("JST['index/foo']").should.not.equal -1
        
  describe 'in production', ->
  
    it 'returns a `pkg`.jst.js script tag pointing to the output templates', ->
      nap
        mode: 'production'
        assets:
          jst:
            foo: ['/test/fixtures/1/foo.jade']
      nap.jst('foo').should.equal "<script src='/assets/foo.jst.js' type='text/javascript'></script>"
      
    it 'points to the cdn if specified', ->
      nap
        cdnUrl: 'http://cdn.com'
        mode: 'production'
        assets:
          jst:
            foo: ['/test/fixtures/1/foo.jade']
      nap.jst('foo').should
        .equal "<script src='http://cdn.com/foo.jst.js' type='text/javascript'></script>"
     
    it 'points to the gzipped file if specified', ->
      nap
        mode: 'production'
        gzip: true
        assets:
          jst:
            foo: ['/test/fixtures/1/foo.jade']
      nap.jst('foo').should
        .equal "<script src='/assets/foo.jst.js.jgz' type='text/javascript'></script>"
     
        
describe '`package`', ->
  
  it 'doesnt minify in anything but production', ->
      nap
        mode: 'test'
        assets:
          js:
            all: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.package()
      fs.readFileSync(process.cwd() + '/public/assets/all.js').toString()
        .indexOf("var a;a=\"foo\"}").should.equal -1
  
  describe 'when in production mode', ->
  
    it 'minifies js', ->
      nap
        mode: 'production'
        assets:
          js:
            all: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
      nap.package()
      fs.readFileSync(process.cwd() + '/public/assets/all.js').toString()
        .indexOf("var a;a=\"foo\"}").should.not.equal -1
      
    it 'minifies jsts', ->
      nap
        mode: 'production'
        assets:
          jst:
            templates: ['/test/fixtures/1/foo.jade', '/test/fixtures/templates/index/foo.jade']
      nap.package()
      fs.readFileSync(process.cwd() + '/public/assets/templates.jst.js').toString()
        .indexOf("\n").should.equal -1
      
    it 'minifies css', ->
      nap
        mode: 'production'
        assets:
          css:
            default: ['/test/fixtures/1/bar.css', '/test/fixtures/1/foo.styl']
      nap.package()
      fs.readFileSync(process.cwd() + '/public/assets/default.css').toString()
        .indexOf("\n").should.equal -1
  
  it 'embeds any image files', ->
    nap
      embedImages: true
      assets:
        css:
          default: ['/test/fixtures/1/bar.css', '/test/fixtures/1/imgs_embed.styl']
    nap.package()
    fs.readFileSync(process.cwd() + '/public/assets/default.css').toString().should.match /data:image/
     
  it 'concatenates the assets and ouputs all of the packages', ->
    nap
      mode: 'production'
      assets:
        js:
          all: ['/test/fixtures/1/bar.coffee', '/test/fixtures/1/foo.js']
        css:
          default: ['/test/fixtures/1/bar.css', '/test/fixtures/1/foo.styl']
        jst:
          templates: ['/test/fixtures/1/foo.jade', '/test/fixtures/templates/index/foo.jade']
    
    nap.package()
    
    jsOut = fs.readFileSync(process.cwd() + '/public/assets/all.js').toString()
    jsOut.indexOf("var foo=\"foo\"").should.not.equal -1
    jsOut.indexOf("var a;a=\"foo\"").should.not.equal -1
    
    cssOut = fs.readFileSync(process.cwd() + '/public/assets/default.css').toString()
    cssOut.indexOf("red").should.not.equal -1
    cssOut.indexOf("#f00").should.not.equal -1
    
    jstOut = fs.readFileSync(process.cwd() + '/public/assets/templates.jst.js').toString()
    jstOut.indexOf("<h2>").should.not.equal -1
    jstOut.indexOf("<h1>").should.not.equal -1
    
  it 'will create gzip versions of assets if specified', (done) ->
    exec 'rm -rf public/assets/'
    nap
      embedImages: true
      gzip: true
      assets:
        css:
          default: ['/test/fixtures/1/bar.css', '/test/fixtures/1/imgs_embed.styl']
    nap.package ->
      path.existsSync '/public/assets/default.css.cgz'
      done()