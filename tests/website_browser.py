"""Actual Chromium project-prefix desktop/mobile/keyboard smoke; no public service."""
import functools
import http.server
import os
import pathlib
import threading
from playwright.sync_api import sync_playwright
ROOT=pathlib.Path(__file__).resolve().parents[1]
work=pathlib.Path(os.environ['SAIVAGE_CARD_WORK_ROOT'])/'u11-browser'
work.mkdir(parents=True,exist_ok=True)
# Explicit prefix mount, with no access to repository/work files.
class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self,path):
        assert path.startswith('/lua-repl-mcp/'),path
        self.path=path.removeprefix('/lua-repl-mcp')
        return super().translate_path(self.path)
    def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'site')))
threading.Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}/lua-repl-mcp/'
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,args=['--no-sandbox'])
        print('Chromium',browser.version)
        for mode,size in [('desktop',{'width':1440,'height':1000}),('mobile',{'width':390,'height':844})]:
            page=browser.new_page(viewport=size)
            failures=[]
            page.on('response',lambda r: failures.append(r.url) if r.status>=400 else None)
            for path,title in [('', 'Persistent Lua execution'),('getting-started/','Install and get'),('manager/','Work with managed'),('custom-host/','Run sessions inside'),('embedding/','Embed in an existing')]:
                page.goto(base+path);page.locator('h1').filter(has_text=title).wait_for()
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),(mode,path,'overflow')
                page.screenshot(path=str(work/f'{mode}-{path.strip("/") or "home"}.png'),scale='css',full_page=True)
                # Code blocks remain scrollable rather than forcing viewport width.
                assert page.locator('main, .col-md-9').count()>0
            page.goto(base)
            if mode=='mobile':
                page.get_by_role('button',name='Toggle navigation').click()
            page.get_by_role('link',name='Getting started',exact=True).first.click()
            assert page.url.endswith('/getting-started/')
            page.goto(base)
            # Tab through real navigation links and activate installation using Enter.
            if mode=='mobile':
                page.get_by_role('button',name='Toggle navigation').focus()
                page.keyboard.press('Enter')
            found=False
            for _ in range(40):
                page.keyboard.press('Tab')
                active=page.evaluate('document.activeElement.textContent.trim()')
                if active=='Getting started':
                    page.keyboard.press('Enter');found=True;break
            assert found, 'installation link unreachable with keyboard'
            page.wait_for_url('**/getting-started/')
            assert not failures, failures
            print('PASS',mode,'home/install/manager/custom-host/embedding, navigation, code layout, keyboard traversal')
            page.close()
        browser.close()
finally:server.shutdown();server.server_close()
