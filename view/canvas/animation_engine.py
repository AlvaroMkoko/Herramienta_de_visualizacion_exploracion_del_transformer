from PySide6.QtQuick import QQuickFramebufferObject
from PySide6.QtCore import Slot
from vispy import gloo
import numpy as np
from OpenGL import GL

class VispyRenderer(QQuickFramebufferObject.Renderer):

    def __init__(self):
        super().__init__()

        self.matrix = np.array([
            [0,1,0,1],
            [1,1,0,0],
            [0,0,1,1],
            [1,0,1,0]
        ], dtype=np.float32)


    def render(self):

        GL.glClearColor(
            0.1,
            0.1,
            0.1,
            1.0
        )

        GL.glClear(
            GL.GL_COLOR_BUFFER_BIT
        )


        filas, columnas = self.matrix.shape


        ancho = 2.0 / columnas
        alto = 2.0 / filas


        for i in range(filas):

            for j in range(columnas):

                valor = self.matrix[i,j]


                if valor == 1:
                    GL.glColor3f(1,0,0)   # rojo

                else:
                    GL.glColor3f(0.2,0.2,0.2)


                x = -1 + j * ancho
                y = 1 - (i+1)*alto


                GL.glBegin(GL.GL_QUADS)


                GL.glVertex2f(
                    x,
                    y
                )

                GL.glVertex2f(
                    x+ancho,
                    y
                )

                GL.glVertex2f(
                    x+ancho,
                    y+alto
                )

                GL.glVertex2f(
                    x,
                    y+alto
                )


                GL.glEnd()


        self.update()


    def synchronize(self, item):

        # Comunicación entre QML y Renderer

        self.matrix = item.matrix



class VispyItem(QQuickFramebufferObject):

    def __init__(self):
        super().__init__()

        self.matrix = np.array([])
        self.setTextureFollowsItemSize(True)
        print("VispyItem creado")
        self.update()

    def createRenderer(self):
        print("ljsdfjlsdjf llaalaas")
        return VispyRenderer()


    @Slot(list)
    def setMatrix(self, matrix):
        print("jfksjdfls")  
        self.matrix = np.array(matrix)  
        self.update()